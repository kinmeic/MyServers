import SwiftUI

struct MainView: View {
    @State private var appState = AppState()
    @State private var promptPassword = ""
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationSplitView(columnVisibility: $appState.columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            HStack(spacing: 0) {
                TerminalContainerView()
                    .frame(minWidth: 500)

                if appState.showHistory {
                    HistoryResizeHandle()
                    HistoryView()
                        .frame(width: appState.historyPanelWidth)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { appState.showHistory.toggle() }) {
                        Label(
                            appState.showHistory ? "隐藏历史" : "显示历史",
                            systemImage: appState.showHistory ? "sidebar.right" : "sidebar.right"
                        )
                    }
                    .labelStyle(.iconOnly)
                    .help(appState.showHistory ? "隐藏命令历史" : "显示命令历史")
                }
            }
        }
        .environment(appState)
        .sheet(item: Binding(
            get: { appState.passwordPrompt },
            set: { request in
                if request == nil {
                    appState.cancelPasswordPrompt()
                }
            }
        )) { request in
            PasswordPromptSheet(
                serverName: request.serverName,
                hostSummary: request.hostSummary,
                password: $promptPassword,
                onCancel: {
                    promptPassword = ""
                    appState.cancelPasswordPrompt()
                },
                onSubmit: {
                    let password = promptPassword
                    promptPassword = ""
                    appState.submitPassword(password)
                }
            )
        }
    }
}

private struct HistoryResizeHandle: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 10)
            .overlay {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let updatedWidth = appState.historyPanelWidth - value.translation.width
                        appState.historyPanelWidth = min(max(updatedWidth, 260), 520)
                    }
            )
            .onHover { isHovering in
                if isHovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

private struct PasswordPromptSheet: View {
    let serverName: String
    let hostSummary: String
    @Binding var password: String
    let onCancel: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("输入密码")
                .font(.title3.weight(.semibold))

            Text(serverName)
                .font(.headline)
            Text(hostSummary)
                .font(.callout)
                .foregroundStyle(.secondary)

            SecureField("密码", text: $password)
                .textFieldStyle(.roundedBorder)

            Text("本次打开 app 期间会临时记住这个密码；下次重新打开时需要重新输入。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("取消", role: .cancel, action: onCancel)
                Spacer()
                Button("连接") {
                    guard !password.isEmpty else { return }
                    onSubmit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
