import Foundation
import Shared

/// Writes the changes of a plan, each file atomically and only if it still holds the buffer the edits were made on.
public enum FixWriter {
    public static func apply(_ plan: FixPlan) throws {
        for change in plan.changes {
            // The planner refuses symbolic links; the real path also covers a link created since.
            let path = RealPath.resolve(change.path.string)
            let url = URL(fileURLWithPath: path)
            let current = try Data(contentsOf: url)
            guard [UInt8](current) == change.original else {
                throw PeripheryError.underlyingError(FixWriterError.fileChanged(change.path.string))
            }

            let permissions = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions]
            try Data(change.fixed).write(to: url, options: .atomic)
            if let permissions {
                try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: path)
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
