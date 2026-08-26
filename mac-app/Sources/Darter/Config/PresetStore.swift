import Foundation

/// One Develop preset available in Lightroom, as read from the TSV file the
/// plugin writes.
struct AvailablePreset: Identifiable, Equatable, Hashable {
    var folder: String
    var name: String
    var id: String { "\(folder)\t\(name)" }
    /// Shown in the picker: name, with folder as context when helpful.
    var displayName: String { "\(name)  —  \(folder)" }
}

/// Reads the list of Lightroom presets the plugin exports to
/// ~/Library/Application Support/Darter/presets.tsv (folder<TAB>name per
/// line). The plugin (re)writes this whenever the Mac app asks it to via the
/// listPresets URL command.
enum PresetStore {
    static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent("Darter", isDirectory: true)
            .appendingPathComponent("presets.tsv")
    }

    static func load() -> [AvailablePreset] {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }
        var presets: [AvailablePreset] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            presets.append(AvailablePreset(folder: String(parts[0]), name: String(parts[1])))
        }
        return presets.sorted { a, b in
            let pa = folderPriority(a.folder), pb = folderPriority(b.folder)
            if pa != pb { return pa < pb }
            if a.folder != b.folder { return a.folder < b.folder }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Favorites first, then Lightroom's built-in User Presets, then every
    /// other folder alphabetically.
    private static func folderPriority(_ folder: String) -> Int {
        switch folder {
        case "Favorites": return 0
        case "User Presets": return 1
        default: return 2
        }
    }
}
