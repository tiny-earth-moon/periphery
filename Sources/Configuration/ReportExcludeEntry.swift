import Foundation
import Yams

/// An entry of the `report_exclude` setting.
///
/// - `pattern`: a path glob, or the compact `<glob>:kind1,kind2` form (resolved later, once the known kinds are available).
/// - `scoped`: a path glob limited to the given result kinds.
/// - `malformed`: an entry that could not be understood, kept so that the error is reported instead of silently dropped.
public enum ReportExcludeEntry: Equatable {
    case pattern(String)
    case scoped(path: String, kinds: [String])
    case malformed(String)

    init(anyValue value: Any) {
        if let entry = value as? ReportExcludeEntry {
            self = entry
        } else if let string = value as? String {
            self = .pattern(string)
        } else if let object = value as? [AnyHashable: Any] {
            let allowedKeys: Set = ["path", "kinds"]
            let keys = Set(object.keys.compactMap { $0 as? String })

            guard let path = object["path"] as? String else {
                self = .malformed("missing string 'path' in \(object)")
                return
            }
            guard keys.isSubset(of: allowedKeys), keys.count == object.count else {
                self = .malformed("unexpected keys in \(object), allowed keys are 'path' and 'kinds'")
                return
            }
            guard let kinds = object["kinds"] as? [String] else {
                self = .malformed("'kinds' must be a list of strings in \(object)")
                return
            }

            self = .scoped(path: path, kinds: kinds)
        } else {
            self = .malformed("\(value)")
        }
    }
}

extension ReportExcludeEntry: Yams.NodeRepresentable {
    public func represented() throws -> Node {
        switch self {
        case let .pattern(string):
            try string.represented()
        case let .scoped(path, kinds):
            try Node(["path": Node(path), "kinds": kinds.represented()])
        case let .malformed(description):
            try description.represented()
        }
    }
}

let reportExcludeSetter: (Any) -> [ReportExcludeEntry]? = { value in
    if let entries = value as? [ReportExcludeEntry] {
        return entries
    } else if let values = value as? [Any] {
        return values.map(ReportExcludeEntry.init(anyValue:))
    } else if value is String {
        return [ReportExcludeEntry(anyValue: value)]
    }

    return nil
}
