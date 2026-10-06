import Foundation

/// Facts about this build, so the version string isn't read from the bundle
/// in several places.
enum AppInfo {
    private static let versionKey = "CFBundleShortVersionString"
    private static let unknownVersion = "?"

    static let version = Bundle.main.infoDictionary?[versionKey] as? String ?? unknownVersion

    /// Releases rather than the repo root: this is where a reader compares
    /// their version against the newest one.
    static let releasesURL = URL(string: "https://github.com/af1/darter/releases")!
}
