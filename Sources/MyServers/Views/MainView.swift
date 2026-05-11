import SwiftUI

struct MainView: View {
    @State private var appState = AppState()

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
