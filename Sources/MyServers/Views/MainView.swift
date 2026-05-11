import SwiftUI

struct MainView: View {
    @State private var appState = AppState()
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
                    Divider()
                    HistoryView()
                        .frame(width: 280)
                }
            }
        }
        .environment(appState)
    }
}
