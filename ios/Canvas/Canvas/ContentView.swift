import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                configurationSection
                photoSection
            }
            .navigationTitle("Canvas")
        }
        .task {
            await viewModel.bootstrap()
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            Task {
                await viewModel.refreshCanvasBattery()
            }
        }
        .onChange(of: viewModel.serverURL) { _ in
            Task {
                await viewModel.refreshCanvasBattery()
            }
        }
    }

    private var configurationSection: some View {
        Section("Configuration") {
            VStack(alignment: .leading, spacing: 6) {
                Text("URL du serveur")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                TextField("http://192.168.0.165:3000", text: $viewModel.serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("URL du BLOOMIN8")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                TextField("http://192.168.0.174", text: $viewModel.canvasURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                HStack(spacing: 6) {
                    Image(systemName: canvasBatteryIconName)
                    Text(canvasBatteryText)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Intervalle entre chaque image (heures)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                TextField("3", text: $viewModel.cronIntervalInHours)
                    .keyboardType(.numberPad)
            }
        }
    }

    private var photoSection: some View {
        Section("Album Photos") {
            if viewModel.isPhotoAccessGranted {
                if viewModel.albums.isEmpty {
                    Text("Aucun album avec photos.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Album", selection: selectedAlbumBinding) {
                        ForEach(viewModel.albums) { album in
                            Text("\(album.title) (\(album.photoCount))")
                                .tag(Optional(album.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Button("Uploader l'album") {
                    viewModel.startUpload()
                }
                .disabled(!viewModel.canStartUpload)

                Button("Start") {
                    viewModel.startPlaylist()
                }
                .disabled(!viewModel.canStartPlaylist)

                Text("Le canvas doit etre up et accessible sur le reseau.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if viewModel.isUploading {
                    ProgressView(value: viewModel.progress.fractionCompleted)
                    Text("\(viewModel.progress.processed)/\(viewModel.progress.total)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if viewModel.isUploading {
                    Button("Annuler l'envoi", role: .destructive) {
                        viewModel.cancelUpload()
                    }
                }

                if viewModel.isStartingPlaylist {
                    ProgressView()
                        .controlSize(.small)
                }
            } else {
                Text("L'app demande l'acces a la phototheque au demarrage.")
                    .foregroundStyle(.secondary)
                Button("Reessayer l'autorisation Photos") {
                    viewModel.requestPhotoAccess()
                }
            }

            if !viewModel.statusText.isEmpty {
                Text(viewModel.statusText)
                    .font(.footnote)
            }

            if let error = viewModel.errorText {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var selectedAlbumBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedAlbumId },
            set: { viewModel.selectedAlbumId = $0 }
        )
    }

    private var canvasBatteryText: String {
        guard let percentage = viewModel.canvasBatteryPercentage else {
            return "Batterie indisponible"
        }
        return "\(percentage)%"
    }

    private var canvasBatteryIconName: String {
        guard let percentage = viewModel.canvasBatteryPercentage else {
            return "battery.0"
        }

        switch percentage {
        case 0 ... 10:
            return "battery.0"
        case 11 ... 35:
            return "battery.25"
        case 36 ... 60:
            return "battery.50"
        case 61 ... 85:
            return "battery.75"
        default:
            return "battery.100"
        }
    }
}
