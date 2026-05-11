import SwiftUI
import SwiftData

struct ServerFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var server: ServerConfig?

    @State private var name = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var password = ""
    @State private var authType: AuthType = .password
    @State private var showPassword = false

    init(server: ServerConfig? = nil) {
        self.server = server
        if let server {
            _name = State(initialValue: server.name)
            _host = State(initialValue: server.host)
            _port = State(initialValue: String(server.port))
            _username = State(initialValue: server.username)
            _authType = State(initialValue: server.authType)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Server") {
                    TextField("Name (e.g. My Server)", text: $name)
                        .textFieldStyle(.roundedBorder)
                    TextField("Host", text: $host)
                        .textFieldStyle(.roundedBorder)
                    TextField("Port", text: $port)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }

                Section("Authentication") {
                    Picker("Method", selection: $authType) {
                        Text("Password").tag(AuthType.password)
                        Text("Private Key").tag(AuthType.privateKey)
                    }
                    .pickerStyle(.segmented)

                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)

                    if authType == .password {
                        HStack {
                            if showPassword {
                                TextField("Password", text: $password)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("Password", text: $password)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 400)

            Spacer()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(height: 420)
    }

    private var isValid: Bool {
        !host.isEmpty && !username.isEmpty
    }

    private func save() {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let server {
            server.name = trimmedName
            server.host = trimmedHost
            server.port = Int(port) ?? 22
            server.username = trimmedUsername
            server.authType = authType
        } else {
            let config = ServerConfig(
                name: trimmedName,
                host: trimmedHost,
                port: Int(port) ?? 22,
                username: trimmedUsername,
                authType: authType
            )
            modelContext.insert(config)

            if authType == .password && !password.isEmpty {
                KeychainManager.savePassword(password, for: config.id)
            }
        }

        try? modelContext.save()
        dismiss()
    }
}
