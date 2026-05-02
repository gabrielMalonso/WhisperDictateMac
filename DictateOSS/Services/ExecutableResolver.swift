import Foundation

enum ExecutableResolver {
    static let commonSearchDirectories = [
        "\(NSHomeDirectory())/.local/bin",
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin"
    ]

    static func resolve(_ executable: String, fallbackName: String? = nil) -> String? {
        let trimmed = executable.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = expandedPath(trimmed)

        if candidate.contains("/") {
            return FileManager.default.isExecutableFile(atPath: candidate) ? candidate : nil
        }

        let executableName = candidate.isEmpty ? fallbackName : candidate
        guard let executableName, !executableName.isEmpty else { return nil }

        for directory in searchDirectories() {
            let path = URL(fileURLWithPath: directory).appendingPathComponent(executableName).path
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    static func expandedPath(_ path: String) -> String {
        NSString(string: path.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
    }

    private static func searchDirectories() -> [String] {
        let pathDirectories = ProcessInfo.processInfo.environment["PATH", default: ""]
            .split(separator: ":")
            .map(String.init)

        var seen = Set<String>()
        return (pathDirectories + commonSearchDirectories).filter { directory in
            let expanded = expandedPath(directory)
            guard !seen.contains(expanded) else { return false }
            seen.insert(expanded)
            return true
        }
    }
}
