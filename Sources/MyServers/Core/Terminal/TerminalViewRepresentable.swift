import SwiftUI
import SwiftTerm

/// NSViewRepresentable wrapper for SwiftTerm's TerminalView.
/// Embeds a raw terminal (not tied to a local process) for SSH remote sessions.
struct TerminalViewRepresentable: NSViewRepresentable {
    let bridge: TerminalBridge
    private let contentInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)

    func makeNSView(context: Context) -> NSView {
        let container = InsetTerminalHostView(contentInsets: contentInsets)
        swapTerminalView(in: container)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        swapTerminalView(in: nsView)
    }

    private func swapTerminalView(in container: NSView) {
        let terminal = bridge.makeView()
        if terminal.superview !== container {
            terminal.removeFromSuperview()
            container.subviews.forEach { $0.removeFromSuperview() }
            container.addSubview(terminal)
        }

        if let container = container as? InsetTerminalHostView {
            container.hostedTerminalView = terminal
            container.layoutSubtreeIfNeeded()
        } else {
            terminal.frame = NSRect(
                x: contentInsets.left,
                y: contentInsets.bottom,
                width: max(0, container.bounds.width - contentInsets.left - contentInsets.right),
                height: max(0, container.bounds.height - contentInsets.top - contentInsets.bottom)
            )
            terminal.autoresizingMask = [.width, .height]
        }
    }
}

private final class InsetTerminalHostView: NSView {
    let contentInsets: NSEdgeInsets
    weak var hostedTerminalView: NSView?

    init(contentInsets: NSEdgeInsets) {
        self.contentInsets = contentInsets
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        hostedTerminalView?.frame = NSRect(
            x: contentInsets.left,
            y: contentInsets.bottom,
            width: max(0, bounds.width - contentInsets.left - contentInsets.right),
            height: max(0, bounds.height - contentInsets.top - contentInsets.bottom)
        )
    }
}
