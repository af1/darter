import AppKit
import Foundation

/// Sends slider adjustments / tool activations to the Darter Lightroom
/// plugin via the lightroom:// URL scheme (Lightroom Classic is already
/// registered with macOS as the receiver for it; the plugin's URLHandler
/// picks up requests addressed to its own LrToolkitIdentifier). No socket,
/// no connection state, no "is Lightroom running" bookkeeping.
///
/// Speed matters here: this runs on every keystroke while the user is
/// dragging a slider via repeated key presses, and it's called from inside
/// the CGEventTap callback, which must return quickly or macOS disables the
/// tap. So: skip plain NSWorkspace.open(_:), which re-resolves "who handles
/// this URL scheme" through Launch Services every call; go straight to the
/// known Lightroom app instead. Don't activate/refocus Lightroom (it's
/// already frontmost, that's why the shortcut fired). And dispatch off the
/// tap callback so a slow round trip never blocks event delivery.
enum LightroomURLSender {
    static let toolkitIdentifier = "com.andrew.darter.lightroom"

    private static let lightroomAppURL: URL? =
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: HotkeyMatcher.lightroomBundleID)

    private static let openConfiguration: NSWorkspace.OpenConfiguration = {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false
        return config
    }()

    static func send(paramName: String, delta: Double, relativeDelta: Double? = nil) {
        var query = [("name", paramName), ("delta", String(delta))]
        if let relativeDelta {
            // The plugin uses this instead of delta for non-raw files.
            query.append(("reldelta", String(relativeDelta)))
        }
        openLightroomURL(query: query)
    }

    static func sendTool(toolName: String) {
        openLightroomURL(query: [("tool", toolName)])
    }

    /// Ask the plugin to (re)write the list of Develop presets to the shared
    /// TSV file, so the Mac app can read them into its preset pickers.
    static func requestPresetList() {
        openLightroomURL(query: [("action", "listPresets")])
    }

    static func applyPreset(folder: String, name: String) {
        openLightroomURL(query: [("action", "applyPreset"), ("folder", folder), ("preset", name)])
    }

    /// ASCII letters and digits only; everything else (including &, =, +, #,
    /// %, spaces, and every byte of multi-byte UTF-8 like emoji or accented
    /// letters) becomes %xx. Deliberately stricter than both URLComponents'
    /// queryItems -- which leaves & and + literal in values, a footgun that
    /// broke "B&W Cool" (& read as a query separator) and "PS08 + Contrast"
    /// -- and CharacterSet.alphanumerics, which passes non-ASCII letters
    /// through raw and can make percentEncodedQuery reject the URL. With this
    /// the plugin's split on & and = is unambiguous, and its %xx byte decode
    /// reconstructs any UTF-8.
    private static let asciiAlphanumerics: CharacterSet =
        CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

    private static func percentEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: asciiAlphanumerics) ?? ""
    }

    private static func openLightroomURL(query: [(String, String)]) {
        // Keys are all fixed ASCII; only values need encoding. Build the
        // query string by hand and hand it to URLComponents already-encoded.
        let queryString = query
            .map { "\($0.0)=\(percentEncode($0.1))" }
            .joined(separator: "&")

        var components = URLComponents()
        components.scheme = "lightroom"
        components.host = toolkitIdentifier
        components.percentEncodedQuery = queryString
        guard let url = components.url else { return }

        DispatchQueue.main.async {
            if let lightroomAppURL {
                NSWorkspace.shared.open(
                    [url],
                    withApplicationAt: lightroomAppURL,
                    configuration: openConfiguration,
                    completionHandler: nil
                )
            } else {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
