import SystemPackage

/// Identifiers of the results that no USR identifies: an unused import, an empty extension, a String Catalog key, a
/// Metal function and a Swift literal naming a Metal function that no `.metal` file declares.
///
/// A baseline stores them, so they hold neither a position nor an absolute path. They survive an edit above the
/// declaration, a move of the file's lines, and another checkout of the project.
public enum SyntheticUsr {
    public static let localizedStringPrefix = "xcstrings:"
    public static let metalFunctionPrefix = "metal:"
    public static let missingMetalFunctionPrefix = "metal-missing:"

    public static func moduleImport(_ module: String, in file: FilePath, projectRoot: FilePath) -> String {
        "import-\(module)-\(relativePath(of: file, to: projectRoot))"
    }

    public static func emptyExtension(of typeName: String, in file: FilePath, projectRoot: FilePath) -> String {
        "empty-extension-\(typeName)-\(relativePath(of: file, to: projectRoot))"
    }

    public static func localizedString(_ key: String, in catalog: FilePath, projectRoot: FilePath) -> String {
        "\(localizedStringPrefix)\(relativePath(of: catalog, to: projectRoot)):\(key)"
    }

    public static func metalFunction(_ name: String, in file: FilePath, projectRoot: FilePath) -> String {
        "\(metalFunctionPrefix)\(relativePath(of: file, to: projectRoot)):\(name)"
    }

    public static func missingMetalFunction(_ name: String, in file: FilePath, projectRoot: FilePath) -> String {
        "\(missingMetalFunctionPrefix)\(relativePath(of: file, to: projectRoot)):\(name)"
    }

    /// The id of the `occurrence`th result (counting from 1) that shares an id with others in a file. The first one
    /// keeps the plain id, so that adding another one after it does not change what a baseline recorded.
    public static func numbered(_ usr: String, occurrence: Int) -> String {
        occurrence <= 1 ? usr : "\(usr)#\(occurrence)"
    }

    // MARK: - Ids of earlier versions

    // These are only computed to read a baseline written by an older version.

    /// An unused import was identified by its position.
    public static func legacyModuleImport(_ module: String, at location: Location, projectRoot: FilePath) -> String {
        "import-\(module)-\(legacyPosition(of: location, projectRoot: projectRoot))"
    }

    /// An empty extension was identified by its position.
    public static func legacyEmptyExtension(of typeName: String, at location: Location, projectRoot: FilePath) -> String {
        "empty-extension-\(typeName)-\(legacyPosition(of: location, projectRoot: projectRoot))"
    }

    /// A String Catalog key was identified by the absolute path of its catalog.
    public static func legacyLocalizedString(_ key: String, in catalog: FilePath) -> String {
        "\(localizedStringPrefix)\(catalog.string):\(key)"
    }

    // MARK: - Private

    private static func relativePath(of file: FilePath, to projectRoot: FilePath) -> String {
        file.relativeTo(projectRoot).string
    }

    private static func legacyPosition(of location: Location, projectRoot: FilePath) -> String {
        [relativePath(of: location.file.path, to: projectRoot), String(location.line), String(location.column)].joined(separator: ":")
    }
}
