import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingError = false
    @State private var showingUploadConfirmation = false
    @State private var toastMessage: String?

    private static let intervalPresets = [1, 2, 3, 4, 6, 8, 12, 24, 48, 72, 168]

    var body: some View {
        mainContent
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
            .modifier(StatusToastBehavior(viewModel: viewModel, toastMessage: $toastMessage))
            .sensoryFeedback(trigger: viewModel.uploadCompletionCount) { _, _ in
                viewModel.lastUploadOutcome == .failure ? .error : .success
            }
            .sensoryFeedback(.success, trigger: viewModel.playlistActionCount)
    }

    private var mainContent: some View {
        NavigationStack {
            Form {
                if !viewModel.isServerReachable {
                    unreachableSection
                }
                playlistSection
                quietHoursSection
                canvasSection
                photoSection
                configurationSection
            }
            .navigationTitle("Canvas")
            .safeAreaInset(edge: .bottom) {
                toast
            }
            .animation(.snappy, value: toastMessage)
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
    }

    @ViewBuilder
    private var toast: some View {
        if let toastMessage {
            Text(toastMessage)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect()
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture { self.toastMessage = nil }
        }
    }

    private func formattedInterval(_ hours: Int) -> String {
        Duration.seconds(hours * 3600).formatted(.units(allowed: [.days, .hours], width: .abbreviated))
    }

    private var intervalChoices: [Int] {
        Set(Self.intervalPresets + [viewModel.cronIntervalInHours]).sorted()
    }

    private var unreachableSection: some View {
        Section {
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
    }

    // Everything that drives the playlist lives here: state, start/pause, interval.
    private var playlistSection: some View {
        Section {
            if let progress = viewModel.playlistProgress {
                HStack(spacing: 12) {
                    currentImageThumbnail

                    VStack(alignment: .leading, spacing: 4) {
                        Label(
                            progress.status == .paused ? "Playlist (en pause)" : "Playlist",
                            systemImage: progress.status == .paused ? "pause.circle.fill" : "photo.stack"
                        )
                        // Grouped digits: albums can exceed 1,000 images.
                        Text(verbatim: "\(progress.displayed.formatted()) / \(progress.total.formatted())")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }

                    Spacer(minLength: 8)

                    PlaylistProgressRing(
                        fraction: progress.total > 0 ? Double(progress.displayed) / Double(progress.total) : 0,
                        tint: progress.status == .paused ? .orange : .accentColor
                    )
                }
                .accessibilityElement(children: .combine)

                // A missed wake-up is reported in the BLOOMIN8 section instead.
                if progress.status == .inProgress, let nextPullDate = progress.nextPullDate, !viewModel.isCanvasSilent {
                    LabeledContent {
                        Text(nextPullDate, format: .relative(presentation: .named))
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Prochaine image", systemImage: "clock.arrow.2.circlepath")
                    }
                }

                Toggle(isOn: pausePlaylistBinding) {
                    Label {
                        Text(pauseToggleLabel)
                    } icon: {
                        Image(systemName: "pause.circle.fill")
                    }
                }
                .disabled(!viewModel.canPausePlaylist && !viewModel.canResumePlaylist)
            } else {
                Button {
                    viewModel.startPlaylist()
                } label: {
                    Label(
                        viewModel.isStartingPlaylist ? "Démarrage..." : "Démarrer la playlist",
                        systemImage: "play.fill"
                    )
                }
                .disabled(!viewModel.canStartPlaylist)
            }

            // Editable before the first start too: the interval is a start parameter.
            Picker(selection: $viewModel.cronIntervalInHours) {
                ForEach(intervalChoices, id: \.self) { hours in
                    Text(formattedInterval(hours)).tag(hours)
                }
            } label: {
                Label {
                    HStack(spacing: 6) {
                        Text("Intervalle")
                        if viewModel.isUpdatingInterval {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                } icon: {
                    Image(systemName: "clock")
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.cronIntervalInHours) { _, newValue in
                guard (1...168).contains(newValue) else { return }
                viewModel.updatePlaylistInterval(newValue)
            }
        } header: {
            Text("Playlist")
        } footer: {
            if viewModel.playlistProgress == nil {
                Text("Pour lancer la playlist, le Canvas doit être accessible sur le réseau. Réveillez-le à partir de l'application BLOOMIN8.")
            } else {
                Text("Le nouvel intervalle sera appliqué au prochain réveil du Canvas.")
            }
        }
    }

    // Portrait thumbnail with the panel's 3:4 ratio. Images are immutable on the
    // server (cache-control: immutable), so URLCache serves repeated loads.
    private var currentImageThumbnail: some View {
        AsyncImage(url: viewModel.currentImageURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "photo")
                .foregroundStyle(.tertiary)
        }
        .frame(width: 48, height: 64)
        .background(.quaternary)
        .clipShape(.rect(cornerRadius: 6))
        .accessibilityLabel("Image affichée sur le Canvas")
    }

    private func formattedHour(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour())
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
                SettingsView(isDeviceURLLocked: viewModel.playlistProgress != nil) {
                    Task {
                        await viewModel.refreshCanvasBattery()
                    }
                }
            } label: {
                Label("Modifier les réglages", systemImage: "gearshape")
            }
        } header: {
            Text("Réglages")
        }
    }

    private var quietHoursSection: some View {
        Section {
            Toggle(isOn: $viewModel.quietHoursEnabled) {
                Label("Mode nuit", systemImage: "moon.fill")
            }

            if viewModel.quietHoursEnabled {
                Picker(selection: $viewModel.quietHoursStart) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(formattedHour(hour)).tag(hour)
                    }
                } label: {
                    Label("Début", systemImage: "moon.stars")
                }
                .pickerStyle(.menu)

                Picker(selection: $viewModel.quietHoursEnd) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(formattedHour(hour)).tag(hour)
                    }
                } label: {
                    Label("Fin", systemImage: "sun.horizon")
                }
                .pickerStyle(.menu)
            }
        } footer: {
            Text("Pause le défilement des images entre \(formattedHour(viewModel.quietHoursStart)) et \(formattedHour(viewModel.quietHoursEnd)), à l'heure de l'iPhone. Le Canvas reste en veille pendant cette période.")
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

    private var canvasSection: some View {
        Section {
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

            if let lastFullChargeDate = viewModel.lastFullChargeDate {
                LabeledContent {
                    Text(lastFullChargeDate, format: .relative(presentation: .named))
                        .foregroundStyle(.secondary)
                } label: {
                    Label("Dernière charge complète", systemImage: "clock.arrow.circlepath")
                }
            }

            if let lastPullDate = viewModel.lastPullDate {
                LabeledContent {
                    Text(lastPullDate, format: .relative(presentation: .named))
                        .foregroundStyle(viewModel.isCanvasSilent ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                } label: {
                    Label("Dernier contact", systemImage: "antenna.radiowaves.left.and.right")
                }
            }
        } header: {
            Text("BLOOMIN8")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if viewModel.isCanvasSilent {
                    Label(
                        "Le Canvas a manqué son réveil prévu : il est peut-être déchargé ou hors de portée du Wi-Fi.",
                        systemImage: "antenna.radiowaves.left.and.right.slash"
                    )
                    .foregroundStyle(.orange)
                }
                // Same threshold as the red battery color.
                if let percentage = viewModel.canvasBatteryPercentage, percentage <= 20 {
                    Label("Batterie faible, pensez à recharger le Canvas", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

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

                    if !viewModel.isUploading {
                        Button {
                            showingUploadConfirmation = true
                        } label: {
                            Label("Uploader l'album", systemImage: "square.and.arrow.up")
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
                            Text("Les photos actuelles restent affichées pendant l'envoi, puis sont remplacées par celles de l'album sélectionné.")
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
        } header: {
            Text("Album")
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

/// Cycle progress as a ring. The center shows a percentage rather than the
/// counts: "1 234 / 1 500" would not fit, a percentage is at most 4 characters.
private struct PlaylistProgressRing: View {
    let fraction: Double
    let tint: Color

    private var percent: Int {
        Int((min(max(fraction, 0), 1) * 100).rounded())
    }

    private var percentLabel: AttributedString {
        var number = AttributedString(percent.formatted())
        number.font = .callout.weight(.semibold)
        var sign = AttributedString("%")
        sign.font = .caption2.weight(.semibold)
        return number + sign
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 5)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            // One text run (not an HStack) so the small "%" sits right against
            // the number, same color.
            Text(percentLabel)
                .contentTransition(.numericText())
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(7)
        }
        .frame(width: 52, height: 52)
        .animation(.snappy, value: fraction)
    }
}

/// Turns the view model's status text into a short-lived toast. Upload steps
/// are already shown by the progress view, so only the final message (done /
/// cancelled) is surfaced once the upload is over.
private struct StatusToastBehavior: ViewModifier {
    let viewModel: AppViewModel
    @Binding var toastMessage: String?

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.statusText) { _, newText in
                guard !viewModel.isUploading else { return }
                show(newText)
            }
            .onChange(of: viewModel.isUploading) { _, isUploading in
                // A locked screen suspends the app and fails the remaining uploads.
                UIApplication.shared.isIdleTimerDisabled = isUploading
                if !isUploading { show(viewModel.statusText) }
            }
            .task(id: toastMessage) {
                guard toastMessage != nil else { return }
                do {
                    try await Task.sleep(for: .seconds(3))
                } catch {
                    return
                }
                toastMessage = nil
            }
    }

    private func show(_ message: String) {
        guard !message.isEmpty else { return }
        toastMessage = message
    }
}

#Preview("Default") {
    ContentView()
}
