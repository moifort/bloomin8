import CanvasGraphQL
import CanvasShared
import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: () -> Void
    // The server keeps the device URL given at playlist start: once a playlist
    // exists, a new address must also be sent to the server.
    let hasPlaylist: Bool

    @State private var serverURL: String
    @State private var deviceURL: String
    private let savedDeviceURL: String
    @State private var testState: TestState = .idle
    @State private var isSaving = false
    @State private var saveError: String?

    private enum TestState: Equatable {
        case idle
        case testing
        case success(latencyMilliseconds: Int)
        case failure(String)
    }

    init(hasPlaylist: Bool = false, onSave: @escaping () -> Void) {
        self.hasPlaylist = hasPlaylist
        self.onSave = onSave
        let defaults = UserDefaults.standard
        let deviceURL = defaults.string(forKey: CanvasSettings.deviceURLKey) ?? CanvasSettings.defaultDeviceURL
        _serverURL = State(initialValue: defaults.string(forKey: CanvasSettings.serverURLKey) ?? CanvasSettings.defaultServerURL)
        _deviceURL = State(initialValue: deviceURL)
        savedDeviceURL = deviceURL
    }

    private var isServerURLValid: Bool {
        CanvasSettings.validatedHTTPURL(serverURL) != nil
    }

    private var isDeviceURLValid: Bool {
        CanvasSettings.validatedHTTPURL(deviceURL) != nil
    }

    var body: some View {
        Form {
            Section {
                urlField("URL du serveur", text: $serverURL, isValid: isServerURLValid)

                Button {
                    testConnection()
                } label: {
                    HStack {
                        Label("Tester la connexion", systemImage: "bolt.horizontal")
                        Spacer()
                        testStateIndicator
                    }
                }
                .disabled(!isServerURLValid || testState == .testing)
            } header: {
                Text("Serveur")
            } footer: {
                Text("Adresse du serveur bloomin8 sur votre réseau local (ex. http://canvas.local:3000).")
            }

            Section {
                urlField("URL du Canvas", text: $deviceURL, isValid: isDeviceURLValid)
            } header: {
                Text("BLOOMIN8")
            } footer: {
                if hasPlaylist {
                    Text("Adresse du Canvas e-ink. Une nouvelle adresse est aussi envoyée au serveur, qui l'utilisera pour réveiller le Canvas.")
                } else {
                    Text("Adresse du Canvas e-ink, utilisée pour le réveiller au lancement de la playlist.")
                }
            }
        }
        .alert("Erreur", isPresented: isShowingSaveError, presenting: saveError) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error)
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Enregistrer") {
                        save()
                    }
                    .disabled(!isServerURLValid || !isDeviceURLValid)
                }
            }
        }
    }

    private func urlField(_ title: LocalizedStringKey, text: Binding<String>, isValid: Bool) -> some View {
        HStack {
            TextField(title, text: text)
                .font(.callout.monospaced())
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !isValid {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("URL invalide")
            }
        }
    }

    @ViewBuilder
    private var testStateIndicator: some View {
        switch testState {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView()
                .controlSize(.small)
        case let .success(latency):
            Label("\(latency) ms", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .labelStyle(.titleAndIcon)
                .font(.callout)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("Connexion impossible")
        }
    }

    private func testConnection() {
        guard let url = CanvasSettings.validatedHTTPURL(serverURL) else { return }
        testState = .testing
        Task {
            let clock = ContinuousClock()
            let started = clock.now
            do {
                _ = try await GraphQLClient.client(for: url).fetchAsync(CanvasGraphQL.HealthQuery())
                let elapsed = started.duration(to: clock.now)
                let milliseconds = Int(elapsed.components.seconds * 1000)
                    + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
                testState = .success(latencyMilliseconds: milliseconds)
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }

    private var isShowingSaveError: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    /// Saves locally, then sends a changed Canvas address to the server so the
    /// running playlist wakes the device at its new address. If the server
    /// refuses, the view stays open with the error: nothing is half-saved.
    private func save() {
        guard
            let serverEndpoint = CanvasSettings.validatedHTTPURL(serverURL),
            let canvasEndpoint = CanvasSettings.validatedHTTPURL(deviceURL)
        else { return }

        let deviceURLChanged = canvasEndpoint.absoluteString != CanvasSettings.validatedHTTPURL(savedDeviceURL)?.absoluteString
        guard hasPlaylist, deviceURLChanged else {
            finishSave()
            return
        }

        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await PlaylistService(baseURL: serverEndpoint).updateCanvasURL(canvasEndpoint)
                finishSave()
            } catch {
                saveError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func finishSave() {
        CanvasSettings.save(serverURL: serverURL, deviceURL: deviceURL)
        WidgetCenter.shared.reloadAllTimelines()
        onSave()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SettingsView(onSave: { })
    }
}
