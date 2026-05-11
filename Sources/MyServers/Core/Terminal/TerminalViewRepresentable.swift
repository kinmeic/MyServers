import SwiftUI
import SwiftTerm

/// NSViewRepresentable wrapper for SwiftTerm's TerminalView.
/// Detects bridge changes to swap the terminal when switching servers.
struct TerminalViewRepresentable: NSViewRepresentable {
    let bridge: TerminalBridge
    private let contentInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    func makeNSView(context: Context) -> InsetTerminalHostView {
        let container = InsetTerminalHostView(contentInsets: contentInsets)
        return container
    }

    @MainActor
    func updateNSView(_ container: InsetTerminalHostView, context: Context) {
        let coordinator = context.coordinator

        // If the bridge changed, remove the old terminal view.
        if bridge !== coordinator.currentBridge {
            coordinator.currentBridge = bridge
            container.subviews.forEach { $0.removeFromSuperview() }
            container.hostedTerminalView = nil
        }

        let targetFrame = NSRect(
            x: contentInsets.left,
            y: contentInsets.bottom,
            width: max(0, container.bounds.width - contentInsets.left - contentInsets.right),
            height: max(0, container.bounds.height - contentInsets.top - contentInsets.bottom)
        )

        let terminal = bridge.makeView(frame: targetFrame)
        if terminal.superview !== container {
            terminal.removeFromSuperview()
            container.subviews.forEach { $0.removeFromSuperview() }
            container.addSubview(terminal)
        }

        container.hostedTerminalView = terminal
        terminal.frame = targetFrame
        terminal.autoresizingMask = [.width, .height]

        if targetFrame.width > 50, targetFrame.height > 50 {
            bridge.syncRemoteSizeToView()
        }
    }

    @MainActor
    final class Coordinator {
        weak var currentBridge: TerminalBridge?
    }
}

final class InsetTerminalHostView: NSView {
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
