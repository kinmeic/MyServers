import SwiftUI
import SwiftTerm

/// NSViewRepresentable wrapper for SwiftTerm's TerminalView.
/// Embeds a raw terminal (not tied to a local process) for SSH remote sessions.
struct TerminalViewRepresentable: NSViewRepresentable {
    let bridge: TerminalBridge

    func makeNSView(context: Context) -> TerminalView {
        let terminal = TerminalView()
        bridge.attach(to: terminal)
        return terminal
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {}
}
