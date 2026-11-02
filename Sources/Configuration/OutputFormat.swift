import Foundation

public enum OutputFormat: String, CaseIterable {
    case xcode
    case csv
    case json
    case checkstyle
    case codeclimate
    case githubActions = "github-actions"
    case githubMarkdown = "github-markdown"
    case gitlabCodeQuality = "gitlab-codequality"

    public static let `default` = OutputFormat.xcode

    @inlinable public var supportsAuxiliaryOutput: Bool {
        self == .xcode
    }

    @inlinable public var supportsColoredOutput: Bool {
        self == .xcode
    }
}
