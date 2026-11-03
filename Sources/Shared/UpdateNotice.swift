import Foundation

public enum UpdateNotice {
    public static let repository = "tiny-earth-moon/outskirts"

    public static var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    }

    public static func releaseNotesURL(tag: String) -> String {
        "https://github.com/\(repository)/releases/tag/\(tag)"
    }

    public static func lines(
        latestVersion: String,
        localVersion: String,
        colorize: (String, Style) -> String
    ) -> [String] {
        [
            colorize("\nUpdate Available!", .boldGreen),
            "Version \(colorize(latestVersion, .bold)) is now available, you are using version \(colorize(localVersion, .bold)).",
            "Release notes: " + colorize(releaseNotesURL(tag: latestVersion), .bold),
            "To disable update checks pass the \(colorize("--disable-update-check", .bold)) option to the \(colorize("scan", .bold)) command.",
        ]
    }

    public enum Style {
        case bold
        case boldGreen
    }
}
