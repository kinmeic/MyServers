import Foundation

/// Tracks and parses command history from terminal output.
/// Can be extended to parse PS1 prompts and extract executed commands.
actor HistoryTracker {
    private var buffer = ""
    private var onCommand: ((String) -> Void)?

    func setHandler(_ handler: @escaping (String) -> Void) {
        self.onCommand = handler
    }

    func feed(_ text: String) {
        buffer += text

        // Simple heuristic: split on newlines and look for prompt patterns.
        // A real implementation would parse the shell's PS1.
        let lines = buffer.components(separatedBy: .newlines)
        guard lines.count > 1 else { return }

        buffer = lines.last ?? ""

        for line in lines.dropLast() {
            if line.hasPrefix("$") || line.hasPrefix("#") || line.hasPrefix("%") {
                let command = line.drop(while: { $0 == " " || $0 == "$" || $0 == "#" || $0 == "%" })
                    .trimmingCharacters(in: .whitespaces)
                if !command.isEmpty {
                    onCommand?(command)
                }
            }
        }
    }
}
