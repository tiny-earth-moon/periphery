import AEXML
import Foundation
import SourceGraph
import SystemPackage

final class InfoPlistParser {
    private static let elements: Set<String> = [
        "UISceneClassName", "UISceneDelegateClassName", "NSPrincipalClass",
        "NSExtensionPrincipalClass", "CLKComplicationPrincipalClass", "WKExtensionDelegateClassName",
    ]
    /// Keys whose value names an asset catalog image: the launch screen image, home screen quick action icons and
    /// the app icon.
    private static let imageNameKeys: Set<String> = ["UIImageName", "UIApplicationShortcutItemIconFile", "CFBundleIconName"]
    private let path: FilePath

    required init(path: FilePath) {
        self.path = path
    }

    func parse() throws -> [AssetReference] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path.string))
        let structure = try AEXMLDocument(xml: data)
        let elements = filter(structure.root)

        return elements.map {
            AssetReference(absoluteName: $0.string, source: .infoPlist)
        }
    }

    /// The asset catalog image names the file references, e.g. `<key>UIImageName</key><string>Launch</string>`
    /// in `UILaunchScreen`.
    func imageNames() throws -> Set<String> {
        let data = try Data(contentsOf: URL(fileURLWithPath: path.string))
        let structure = try AEXMLDocument(xml: data)

        return Set(filter(structure.root, keys: Self.imageNameKeys).filter { $0.name == "string" }.map(\.string))
    }

    // MARK: - Private

    private func filter(_ parent: AEXMLElement, keys: Set<String> = InfoPlistParser.elements) -> [AEXMLElement] {
        var elements: [AEXMLElement] = []

        for (i, child) in parent.children.enumerated() {
            if child.name == "key", keys.contains(child.string) {
                if let nextElement = parent.children[safe: i + 1] {
                    elements.append(nextElement)
                }
            }

            elements += filter(child, keys: keys)
        }

        return elements
    }
}
