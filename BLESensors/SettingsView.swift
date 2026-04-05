import SwiftUI

struct SettingsView: View {
    var store: SensorStore
    @Environment(\.dismiss) private var dismiss

    @State private var email = UserDefaults.standard.string(forKey: "mysaEmail") ?? ""
    @State private var password = UserDefaults.standard.string(forKey: "mysaPassword") ?? ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    private var client: MysaClient { store.mysaClient }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2).bold()
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.return)
            }

            Divider()

            // HomePod section
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Enable HomePod Sensors", isOn: Binding(
                    get: { store.homepodEnabled },
                    set: { store.homepodEnabled = $0 }
                ))
                .font(.headline)

                if store.homepodEnabled {
                    HStack(spacing: 6) {
                        if store.homepodReader.isAuthorized {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("HomeKit connected").foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "clock").foregroundStyle(.secondary)
                            Text("Connecting to HomeKit…").foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .padding(.leading, 4)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: store.homepodEnabled)

            Divider()

            // Mysa section
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable Mysa Thermostats", isOn: Binding(
                    get: { store.mysaEnabled },
                    set: { store.mysaEnabled = $0 }
                ))
                .font(.headline)

                if store.mysaEnabled {
                    VStack(alignment: .leading, spacing: 10) {
                        if client.isAuthenticated {
                            // Signed-in state
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(client.statusMessage)
                                    .foregroundStyle(.secondary)
                            }
                            Button("Sign Out", role: .destructive) {
                                client.signOut()
                                store.removeMysaSensors()
                                password = ""
                                UserDefaults.standard.removeObject(forKey: "mysaPassword")
                            }
                        } else {
                            // Sign-in form
                            LabeledContent("Email") {
                                TextField("account@example.com", text: $email)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 220)
                            }

                            LabeledContent("Password") {
                                SecureField("Password", text: $password)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 220)
                            }

                            HStack {
                                Button(isBusy ? "Signing In…" : "Sign In") {
                                    Task { await signIn() }
                                }
                                .disabled(email.isEmpty || password.isEmpty || isBusy)
                                .keyboardShortcut(.return, modifiers: [])

                                if let err = errorMessage {
                                    Text(err)
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .padding(.leading, 4)
                    .animation(.easeInOut(duration: 0.2), value: client.isAuthenticated)
                }
            }

        }
        .padding(20)
        .frame(width: 380)
        .animation(.easeInOut(duration: 0.15), value: store.mysaEnabled)
        .animation(.easeInOut(duration: 0.15), value: client.isAuthenticated)
    }

    private func signIn() async {
        isBusy = true
        errorMessage = nil
        UserDefaults.standard.set(email, forKey: "mysaEmail")
        UserDefaults.standard.set(password, forKey: "mysaPassword")

        do {
            try await client.signIn(email: email, password: password)
            // Kick off an immediate poll now that we're authenticated
            await store.pollMysaNow()
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }
}
