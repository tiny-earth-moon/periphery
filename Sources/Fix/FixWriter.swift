import Foundation
import Shared

/// Writes the changes of a plan, each file atomically and only if it still holds the buffer the edits were made on.
public enum FixWriter {
    public static func apply(_ plan: FixPlan) throws {
        for change in plan.changes {
            let url = URL(fileURLWithPath: change.path.string)
            let current = try Data(contentsOf: url)
            guard [UInt8](current) == change.original else {
                throw PeripheryError.underlyingError(FixWriterError.fileChanged(change.path.string))
            }

            let permissions = try FileManager.default.attributesOfItem(atPath: change.path.string)[.posixPermissions]
            try Data(change.fixed).write(to: url, options: .atomic)
            if let permissions {
                try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: change.path.string)
            }
        }
    }
}

enum FixWriterError: Error, CustomStringConvertible {
    case fileChanged(String)

    var description: String {
        switch self {
        case let .fileChanged(path):
            "\(path) changed while the fixes were being prepared, nothing more was written."
        }
    }
}
