import Extensions
import Foundation

enum SwiftVersionParser {
    static func parse(_ fullVersion: String) throws -> VersionString {
        let parts = fullVersion.components(separatedBy: "Swift version")

        guard parts.count > 1,
              let rawVersion = parts.last?.split(separator: " ").first,
              let version = rawVersion.split(separator: "-").first,
              version.first?.isNumber == true
        else {
            throw PeripheryError.swiftVersionParseError(fullVersion: fullVersion)
        }

        return String(version)
    }
}
