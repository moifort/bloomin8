import SwiftUI

struct ContentView: View {
    @State private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            Form {
                configurationSection
                batterySection
                photoSection
            }
            .navigationTitle("Canvas")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refreshCanvasBattery()
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
            }
        }
        .onChange(of: viewModel.serverURL) { _, _ in
            Task {
                await viewModel.refreshCanvasBattery()
            }
        }
        .alert("Erreur", isPresented: $showingError, presenting: viewModel.errorText) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error)
        }
        .onChange(of: viewModel.errorText) { _, newError in
            showingError = newError != nil
        }
        .sensoryFeedback(.success, trigger: viewModel.progress.uploaded)
        .sensoryFeedback(.error, trigger: viewModel.progress.failed)
    }

    private var configurationSection: some View {
        Section {
            LabeledContent {
                TextField("http://192.168.0.165:3000", text: $viewModel.serverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Serveur", systemImage: "server.rack")
            }

            LabeledContent {
                TextField("http://192.168.0.174", text: $viewModel.canvasURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("BLOOMIN8", systemImage: "photo.on.rectangle.angled")
            }

            LabeledContent {
                TextField("3", text: $viewModel.cronIntervalInHours)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            } label: {
                Label("Intervalle (heures)", systemImage: "clock")
            }
        } header: {
            Text("Configuration")
        }
    }
    
    private var batterySection: some View {
        Section("État du Canvas") {
            HStack {
                Label {
                    Text("Batterie")
                } icon: {
                    Image(systemName: canvasBatteryIconName)
                        .foregroundStyle(canvasBatteryColor)
                }
                
                Spacer()
                
                Text(canvasBatteryText)
                    .foregroundStyle(canvasBatteryColor)
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())
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
        } header: {
            Text("Photos")
        }
        
        if viewModel.isPhotoAccessGranted && !viewModel.albums.isEmpty && !viewModel.isUploading {
            Section {
                Button("Uploader l'album") {
                    viewModel.startUpload()
                }
                .disabled(!viewModel.canStartUpload)
                
                Button(viewModel.isStartingPlaylist ? "Démarrage..." : "Démarrer la playlist") {
                    viewModel.startPlaylist()
                }
                .disabled(!viewModel.canStartPlaylist)
            } footer: {
                Text("Pour lancer la playlist le canvas doit être accessible sur le réseau. Reveillez le a partir de l'application BLOOMIN8")
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

    private var canvasBatteryText: String {
        guard let percentage = viewModel.canvasBatteryPercentage else {
            return "Indisponible"
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
#Preview {
    ContentView()
}

