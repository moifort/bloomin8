import CanvasGraphQL
import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: () -> Void

    @State private var serverURL: String
    @State private var deviceURL: String
    @State private var testState: TestState = .idle

    private enum TestState: Equatable {
        case idle
        case testing
        case success(latencyMilliseconds: Int)
        case failure(String)
    }

    init(onSave: @escaping () -> Void) {
        self.onSave = onSave
        let defaults = UserDefaults.standard
        _serverURL = State(initialValue: defaults.string(forKey: CanvasSettings.serverURLKey) ?? CanvasSettings.defaultServerURL)
        _deviceURL = State(initialValue: defaults.string(forKey: CanvasSettings.deviceURLKey) ?? CanvasSettings.defaultDeviceURL)
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
                Text("Adresse du serveur bloomin8 sur votre réseau local (ex. http://192.168.0.165:3000).")
            }

            Section {
                urlField("URL du Canvas", text: $deviceURL, isValid: isDeviceURLValid)
            } header: {
                Text("BLOOMIN8")
            } footer: {
                Text("Adresse du Canvas e-ink, utilisée pour le réveiller au lancement de la playlist.")
            }
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") {
                    save()
                }
                .disabled(!isServerURLValid || !isDeviceURLValid)
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

    private func save() {
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
