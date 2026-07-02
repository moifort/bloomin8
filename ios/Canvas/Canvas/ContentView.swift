import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingError = false
    @State private var showingUploadConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                configurationSection
                quietHoursSection
                batterySection
                photoSection
            }
            .refreshable {
                await viewModel.refreshCanvasBattery()
                viewModel.reloadAlbums()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refreshCanvasBattery()
                            viewModel.reloadAlbums()
                        }
                    } label: {
                        Label("Actualiser", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isUploading || viewModel.isStartingPlaylist)
                }
            }
        }
        .task {
            await viewModel.bootstrap()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await viewModel.refreshCanvasBattery()
                viewModel.reloadAlbums()
            }
        }
        .alert("Erreur", isPresented: $showingError, presenting: viewModel.errorText) { _ in
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: { error in
            Text(error)
        }
        .onChange(of: viewModel.errorText) { _, newError in
            showingError = newError != nil
        }
        .sensoryFeedback(trigger: viewModel.uploadCompletionCount) { _, _ in
            viewModel.lastUploadOutcome == .failure ? .error : .success
        }
        .sensoryFeedback(.success, trigger: viewModel.playlistActionCount)
    }

    private var configurationSection: some View {
        Section {
            LabeledContent {
                Text(viewModel.serverURL)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } label: {
                Label("Serveur", systemImage: "server.rack")
            }

            LabeledContent {
                Text(viewModel.canvasURL)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } label: {
                Label("BLOOMIN8", systemImage: "photo.on.rectangle.angled")
            }

            NavigationLink {
                SettingsView {
                    Task {
                        await viewModel.refreshCanvasBattery()
                    }
                }
            } label: {
                Label("Modifier les réglages", systemImage: "gearshape")
            }

            LabeledContent {
                HStack(spacing: 8) {
                    Button {
                        viewModel.cronIntervalInHours = max(1, viewModel.cronIntervalInHours - 1)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.cronIntervalInHours <= 1)
                    .accessibilityLabel("Réduire l'intervalle")

                    HStack(spacing: 2) {
                        Text("\(viewModel.cronIntervalInHours)")
                            .monospacedDigit()
                        Text("h")
                            .foregroundStyle(.secondary)
                        if viewModel.isUpdatingInterval {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.leading, 4)
                        }
                    }

                    Button {
                        viewModel.cronIntervalInHours = min(168, viewModel.cronIntervalInHours + 1)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.cronIntervalInHours >= 168)
                    .accessibilityLabel("Augmenter l'intervalle")
                }
            } label: {
                Label("Intervalle", systemImage: "clock")
            }
            .disabled(!viewModel.canEditInterval)
            .onChange(of: viewModel.cronIntervalInHours) { _, newValue in
                guard (1...168).contains(newValue) else { return }
                viewModel.updatePlaylistInterval(newValue)
            }
        } footer: {
            if viewModel.canEditInterval {
                Text("Le nouvel intervalle sera appliqué au prochain réveil du Canvas.")
            } else {
                Text("Démarrez une playlist pour pouvoir modifier l'intervalle.")
            }
        }
    }

    private var quietHoursSection: some View {
        Section {
            Toggle(isOn: pausePlaylistBinding) {
                Label {
                    Text(pauseToggleLabel)
                } icon: {
                    Image(systemName: "pause.circle.fill")
                }
            }
            .disabled(!viewModel.canPausePlaylist && !viewModel.canResumePlaylist)

            Group {
                Toggle(isOn: $viewModel.quietHoursEnabled) {
                    Label("Mode nuit", systemImage: "moon.fill")
                }

                if viewModel.quietHoursEnabled {
                    Picker(selection: $viewModel.quietHoursStart) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text("\(hour)h").tag(hour)
                        }
                    } label: {
                        Label("Début", systemImage: "moon.stars")
                    }
                    .pickerStyle(.menu)

                    Picker(selection: $viewModel.quietHoursEnd) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text("\(hour)h").tag(hour)
                        }
                    } label: {
                        Label("Fin", systemImage: "sun.horizon")
                    }
                    .pickerStyle(.menu)

                    NavigationLink {
                        TimeZonePickerView(selection: $viewModel.quietHoursTimezone)
                    } label: {
                        LabeledContent {
                            Text(viewModel.quietHoursTimezone.replacingOccurrences(of: "_", with: " "))
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Fuseau horaire", systemImage: "globe")
                        }
                    }
                }
            }
            .disabled(viewModel.isPlaylistPaused)
        } footer: {
            Text("Pause le défilement des images entre \(viewModel.quietHoursStart)h et \(viewModel.quietHoursEnd)h dans le fuseau horaire sélectionné. Le Canvas reste en veille pendant cette période.")
        }
    }

    private var pausePlaylistBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isPlaylistPaused },
            set: { newValue in
                if newValue {
                    viewModel.pausePlaylist()
                } else {
                    viewModel.resumePlaylist()
                }
            }
        )
    }

    private var pauseToggleLabel: String {
        if viewModel.isPausingPlaylist {
            return viewModel.isPlaylistPaused
                ? String(localized: "Reprise...")
                : String(localized: "Mise en pause...")
        }
        return String(localized: "Mettre en pause")
    }

    private var batterySection: some View {
        Section {
            if !viewModel.isServerReachable {
                HStack {
                    Label("Serveur injoignable", systemImage: "wifi.exclamationmark")
                        .foregroundStyle(.orange)

                    Spacer()

                    Button("Réessayer") {
                        Task {
                            await viewModel.refreshCanvasBattery()
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.isRefreshingStatus)
                }
            }

            HStack {
                Label {
                    Text("Batterie")
                } icon: {
                    Image(systemName: canvasBatteryIconName)
                        .foregroundStyle(canvasBatteryColor)
                }

                Spacer()

                if viewModel.canvasBatteryPercentage == nil && viewModel.isRefreshingStatus {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(canvasBatteryPercentageText)
                        .foregroundStyle(canvasBatteryColor)
                        .fontWeight(.semibold)
                        .contentTransition(.numericText())
                }
            }
            .opacity(viewModel.isServerReachable ? 1 : 0.5)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Batterie du Canvas")
            .accessibilityValue(
                viewModel.canvasBatteryPercentage.map { String(localized: "\($0) pour cent") }
                    ?? String(localized: "Indisponible")
            )

            if let days = viewModel.lastFullChargeDays {
                LabeledContent {
                    Text("^[\(days) jour](inflect: true)")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Dernière charge complète", systemImage: "clock.arrow.circlepath")
                }
            }

            if let lastPullDate = viewModel.lastPullDate {
                LabeledContent {
                    Text(lastPullDate, format: .relative(presentation: .named))
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Dernier contact", systemImage: "antenna.radiowaves.left.and.right")
                }
            }

            if let progress = viewModel.playlistProgress {
                LabeledContent {
                    HStack(spacing: 6) {
                        if progress.status == .paused {
                            Image(systemName: "pause.circle.fill")
                                .foregroundStyle(.orange)
                        }
                        Text("\(progress.displayed)/\(progress.total)")
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                } label: {
                    Label(progress.status == .paused ? "Playlist (en pause)" : "Playlist", systemImage: "photo.stack")
                }
            }
        } footer: {
            if let percentage = viewModel.canvasBatteryPercentage, percentage < 10 {
                Label("Batterie faible, pensez à recharger le Canvas", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        Section {
            if viewModel.isPhotoAccessGranted {
                if viewModel.albums.isEmpty {
                    ContentUnavailableView {
                        Label("Aucun album", systemImage: "photo.on.rectangle.angled")
                    } description: {
                        Text("Aucun album contenant des photos n'a été trouvé.")
                    }
                } else {
                    LabeledContent {
                        Picker("Album", selection: selectedAlbumBinding) {
                            ForEach(viewModel.albums) { album in
                                Text("\(album.title) (\(album.photoCount))")
                                    .tag(Optional(album.id))
                            }
                        }
                        .labelsHidden()
                    } label: {
                        Label("Album", systemImage: "photo.stack")
                    }

                    if viewModel.isUploading {
                        VStack(spacing: 12) {
                            ProgressView(value: viewModel.progress.fractionCompleted) {
                                HStack {
                                    Text("Upload en cours")
                                    Spacer()
                                    Text("\(viewModel.progress.processed)/\(viewModel.progress.total)")
                                }
                                .font(.subheadline)
                            }

                            HStack {
                                Label("\(viewModel.progress.uploaded)", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)

                                Spacer()

                                if viewModel.progress.failed > 0 {
                                    Label("\(viewModel.progress.failed)", systemImage: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                            .font(.caption)

                            Button("Annuler", role: .destructive) {
                                viewModel.cancelUpload()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }

                    if !viewModel.statusText.isEmpty {
                        Label {
                            Text(viewModel.statusText)
                                .font(.footnote)
                        } icon: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Accès Photos requis", systemImage: "photo.badge.exclamationmark")
                } description: {
                    Text("L'application a besoin d'accéder à vos photos pour uploader un album.")
                } actions: {
                    Button("Autoriser l'accès") {
                        viewModel.requestPhotoAccess()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }

        if viewModel.isPhotoAccessGranted && !viewModel.albums.isEmpty && !viewModel.isUploading {
            Section {
                Button("Uploader l'album") {
                    showingUploadConfirmation = true
                }
                .disabled(!viewModel.canStartUpload)
                .confirmationDialog(
                    "Remplacer les photos du Canvas ?",
                    isPresented: $showingUploadConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Tout remplacer", role: .destructive) {
                        viewModel.startUpload()
                    }
                    Button("Annuler", role: .cancel) { }
                } message: {
                    Text("Toutes les photos actuellement sur le serveur seront supprimées avant l'envoi de l'album sélectionné.")
                }

                if !viewModel.isPlaylistRunning && !viewModel.isPlaylistPaused {
                    Button(viewModel.isStartingPlaylist ? "Démarrage..." : "Démarrer la playlist") {
                        viewModel.startPlaylist()
                    }
                    .disabled(!viewModel.canStartPlaylist)
                }
            } footer: {
                Text("Pour lancer la playlist, le Canvas doit être accessible sur le réseau. Réveillez-le à partir de l'application BLOOMIN8.")
                    .font(.footnote)
            }
        }
    }

    private var selectedAlbumBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedAlbumId },
            set: { viewModel.selectedAlbumId = $0 }
        )
    }

    private var canvasBatteryPercentageText: String {
        guard let percentage = viewModel.canvasBatteryPercentage else {
            return String(localized: "Indisponible")
        }

        return "\(percentage)%"
    }

    private var canvasBatteryIconName: String {
        guard let percentage = viewModel.canvasBatteryPercentage else {
            return "battery.0percent"
        }

        switch percentage {
        case 0...10:
            return "battery.0percent"
        case 11...35:
            return "battery.25percent"
        case 36...60:
            return "battery.50percent"
        case 61...85:
            return "battery.75percent"
        default:
            return "battery.100percent"
        }
    }

    private var canvasBatteryColor: Color {
        guard let percentage = viewModel.canvasBatteryPercentage else {
            return .secondary
        }

        switch percentage {
        case 0...20:
            return .red
        case 21...40:
            return .orange
        default:
            return .green
        }
    }
}

#Preview("Default") {
    ContentView()
}

struct TimeZonePickerView: View {
    @Binding var selection: String
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredTimezones: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(filteredTimezones, id: \.self) { tz in
            Button {
                selection = tz
                dismiss()
            } label: {
                HStack {
                    Text(tz.replacingOccurrences(of: "_", with: " "))
                    Spacer()
                    if tz == selection {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .searchable(text: $searchText, prompt: "Rechercher")
        .navigationTitle("Fuseau horaire")
        .navigationBarTitleDisplayMode(.inline)
    }
}
