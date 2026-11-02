import Foundation
import Shared
import SystemPackage

/// A baseline set of declarations that are excluded from results.
public enum Baseline: Codable {
    case v1(usrs: [String])

    public var usrs: Set<String> {
        switch self {
        case let .v1(usrs):
            Set(usrs)
        }
    }

    /// Reads a baseline file, reporting the key at fault when the file is not a baseline.
    public static func load(from path: FilePath) throws -> Baseline {
        let data = try Data(contentsOf: path.url)

        do {
            return try JSONDecoder().decode(Baseline.self, from: data)
        } catch let error as DecodingError {
            throw PeripheryError.usageError("Invalid baseline \(path.string): \(error.readableReason())")
        }
    }
}
