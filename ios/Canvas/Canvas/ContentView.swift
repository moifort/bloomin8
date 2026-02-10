import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                photoSection
                uploadSection
            }
            .navigationTitle("Canvas")
        }
        .task {
            await viewModel.bootstrap()
        }
    }

    private var serverSection: some View {
        Section("Serveur") {
            TextField("http://192.168.0.165:3000", text: $viewModel.serverURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            Button("Lancer la playlist") {
                viewModel.startPlaylist()
            }
            .disabled(!viewModel.canStartPlaylist)

            if viewModel.isStartingPlaylist {
                ProgressView()
                    .controlSize(.small)
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

                Button("Recharger les albums") {
                    viewModel.reloadAlbums()
                }
            } else {
                Text("L'app doit acceder a ta phototheque.")
                    .foregroundStyle(.secondary)
                Button("Autoriser Photos") {
                    viewModel.requestPhotoAccess()
                }
            }
        }
    }

    private var uploadSection: some View {
        Section("Upload") {
            Text("Conversion appliquee: JPEG 1200x1600, orientation envoyee en P/L")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if viewModel.isUploading {
                ProgressView(value: viewModel.progress.fractionCompleted)
                Text("\(viewModel.progress.processed)/\(viewModel.progress.total)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

            Button("Convertir et envoyer") {
                viewModel.startUpload()
            }
            .disabled(!viewModel.canStartUpload)

            if viewModel.isUploading {
                Button("Annuler", role: .destructive) {
                    viewModel.cancelUpload()
                }
            }
        }
    }

    private var selectedAlbumBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedAlbumId },
            set: { viewModel.selectedAlbumId = $0 }
        )
    }
}
