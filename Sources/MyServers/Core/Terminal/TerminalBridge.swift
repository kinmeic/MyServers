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
    private var terminalView: TerminalView?
    private var commandBuffer: String = ""
    var onCommandEntered: ((String) -> Void)?

    init(session: SSHSession) {
        self.session = session
    }

    /// Return an existing TerminalView or create and wire one.
    @MainActor
    func makeView() -> TerminalView {
        if let tv = terminalView {
            return tv
        }
        let tv = TerminalView()
        terminalView = tv
        attach(to: tv)
        return tv
    }

    @MainActor
    private func attach(to view: TerminalView) {
        view.terminalDelegate = self

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

    /// Forward keystrokes to SSH session and buffer command input.
    private nonisolated func send(_ data: ArraySlice<UInt8>) {
        let bytes = Array(data)
        Task { @MainActor in
            await session.send(Data(bytes))
            self.processInput(bytes)
        }
    }

    @MainActor
    private func processInput(_ bytes: [UInt8]) {
        for byte in bytes {
            switch byte {
            case 0x0D: // Enter / Return
                let command = commandBuffer
                commandBuffer = ""
                if !command.isEmpty {
                    onCommandEntered?(command)
                }
            case 0x7F: // Backspace
                if !commandBuffer.isEmpty {
                    commandBuffer.removeLast()
                }
            case 0x1B: // Escape — skip simple escape sequences
                continue
            default:
                // Capture printable ASCII only
                if byte >= 0x20 && byte <= 0x7E {
                    commandBuffer += String(UnicodeScalar(byte))
                }
            }
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
