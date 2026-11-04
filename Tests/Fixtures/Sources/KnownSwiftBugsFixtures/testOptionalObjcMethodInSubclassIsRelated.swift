import Foundation

open class FixtureOptionalBase: NSObject, FileManagerDelegate {}

public class FixtureOptionalSubclass: FixtureOptionalBase {
    func fileManager(_: FileManager, shouldRemoveItemAtPath _: String) -> Bool {
        false
    }
}
