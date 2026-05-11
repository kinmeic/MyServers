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
            VStack(alignment: .leading, spacing: 6) {
                Text(server == nil ? "新增服务器" : "编辑服务器")
                    .font(.title3.weight(.semibold))
                Text("保存后会自动出现在左侧列表，点选即可连接。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Form {
                Section("服务器") {
                    TextField("名称（例如：生产服务器）", text: $name)
                    TextField("主机地址", text: $host)

                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        TextField("端口", text: $port)
                            .frame(width: 90)

                        if parsedPort == nil {
                            Label("端口需为 1-65535", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("认证") {
                    if authType != .password {
                        Label("当前版本仅支持密码登录。", systemImage: "info.circle")
                            .foregroundStyle(.orange)

                        Button("切换为密码登录") {
                            authType = .password
                        }
                    }

                    TextField("用户名", text: $username)

                    if authType == .password {
                        HStack {
                            if showPassword {
                                TextField(passwordPlaceholder, text: $password)
                            } else {
                                SecureField(passwordPlaceholder, text: $password)
                            }

                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                        }

                        if server != nil {
                            Text("密码留空则保留当前 Keychain 中的密码。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 440)

            Spacer()

            HStack {
                Button("取消", role: .cancel) { dismiss() }
                Spacer()
                Button("保存", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(height: 480)
    }

    private var isValid: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parsedPort != nil &&
        authType == .password
    }

    private var parsedPort: Int? {
        guard let parsed = Int(port), (1...65535).contains(parsed) else { return nil }
        return parsed
    }

    private var passwordPlaceholder: String {
        server == nil ? "密码" : "输入新密码"
    }

    private func save() {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsedPort else { return }

        if let server {
            server.name = trimmedName
            server.host = trimmedHost
            server.port = parsedPort
            server.username = trimmedUsername
            server.authType = authType

            if authType == .password {
                if password.isEmpty {
                    // Keep the existing Keychain password when editing.
                } else {
                    KeychainManager.savePassword(password, for: server.id)
                }
            } else {
                KeychainManager.deletePassword(for: server.id)
            }
        } else {
            let config = ServerConfig(
                name: trimmedName,
                host: trimmedHost,
                port: parsedPort,
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
