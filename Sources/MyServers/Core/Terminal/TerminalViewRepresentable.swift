import SwiftUI
import SwiftTerm

/// NSViewRepresentable wrapper for SwiftTerm's TerminalView.
/// Embeds a raw terminal (not tied to a local process) for SSH remote sessions.
struct TerminalViewRepresentable: NSViewRepresentable {
    let bridge: TerminalBridge

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        swapTerminalView(in: container)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Remove existing terminal subviews and add the correct one
        swapTerminalView(in: nsView)
    }

    private func swapTerminalView(in container: NSView) {
        container.subviews.forEach { $0.removeFromSuperview() }
        let terminal = bridge.makeView()
        terminal.frame = container.bounds
        terminal.autoresizingMask = [.width, .height]
        container.addSubview(terminal)
    }
}
