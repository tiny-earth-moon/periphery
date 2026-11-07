import Foundation
import SystemPackage

public final class SourceFile {
    public let path: FilePath
    public let modules: Set<String>
    /// The builds the file's index units were compiled for, empty when not known.
    public let variants: Set<IndexVariant>
    public var importStatements: [ImportStatement] = []
    public var importsSwiftTesting = false
    public var usesDistributedModifier = false

    private let hashValueCache: Int

    public init(path: FilePath, modules: Set<String>, variants: Set<IndexVariant> = []) {
        self.path = path
        self.modules = modules
        self.variants = variants
        hashValueCache = path.hashValue
    }
}

extension SourceFile: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(hashValueCache)
    }
}

extension SourceFile: Equatable {
    public static func == (lhs: SourceFile, rhs: SourceFile) -> Bool {
        lhs === rhs || lhs.path == rhs.path
    }
}

extension SourceFile: Comparable {
    public static func < (lhs: SourceFile, rhs: SourceFile) -> Bool {
        lhs.path.string < rhs.path.string
    }
}
