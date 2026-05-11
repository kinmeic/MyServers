import Foundation
import AppKit
import SwiftTerm

/// Bridges SwiftTerm's TerminalView with a Citadel SSH session.
/// - Receives data from SSH → feeds to TerminalView (main thread)
/// - Receives keystrokes from TerminalView → sends to SSH session
@MainActor
@Observable
final class TerminalBridge: @unchecked Sendable {
    private let session: SSHSession
    private weak var terminalView: TerminalView?

    init(session: SSHSession) {
        self.session = session
    }

    @MainActor
    func attach(to view: TerminalView) {
        self.terminalView = view
        view.terminalDelegate = self

        // Wire SSH output → terminal
        Task {
            await session.setDataHandler { [weak self] data in
                guard let self else { return }
                let slice = ArraySlice([UInt8](data))
                DispatchQueue.main.async {
                    self.terminalView?.feed(byteArray: slice)
                }
            }
        }
    }

    /// Forward keystrokes to SSH session.
    private nonisolated func send(_ data: ArraySlice<UInt8>) {
        Task {
            await session.send(Data(data))
        }
    }
}

// MARK: - TerminalViewDelegate

extension TerminalBridge: TerminalViewDelegate {
    nonisolated func scrolled(source: SwiftTerm.TerminalView, position: Double) {}

    nonisolated func saveFile(source: SwiftTerm.TerminalView, data: Data, fileName: String) {}

    nonisolated func updateTitle(source: SwiftTerm.TerminalView, title: String) {}

    nonisolated func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}

    nonisolated func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
        Task {
            await session.resize(cols: newCols, rows: newRows)
        }
    }

    nonisolated func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}

    nonisolated func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String: String]) {
        if let url = URL(string: link) {
            NSWorkspace.shared.open(url)
        }
    }

    nonisolated func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
        send(data)
    }

    nonisolated func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {
        if let text = String(data: content, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    nonisolated func clipboardPaste(source: SwiftTerm.TerminalView) -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    nonisolated func mouseModeChanged(source: SwiftTerm.TerminalView) {}

    nonisolated func windowCommand(source: SwiftTerm.TerminalView, command: SwiftTerm.Terminal.WindowManipulationCommand, parameter: Int) {}

    nonisolated func emit(command: String, data: Data?) {}

    nonisolated func print(terminal: SwiftTerm.Terminal, data: String, position: (Int, Int)) {}

    nonisolated func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}
}
