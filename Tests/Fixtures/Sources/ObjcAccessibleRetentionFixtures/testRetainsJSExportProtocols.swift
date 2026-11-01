import Foundation
import JavaScriptCore

protocol FixtureProtocolJSExport: JSExport {
    func exported()
}

protocol FixtureProtocolJSExportIntermediate: FixtureProtocolJSExport {
    var intermediateValue: Int { get }
}

protocol FixtureProtocolJSExportWitness {
    func witness()
}

class FixtureClassJSExport: NSObject, FixtureProtocolJSExportIntermediate, FixtureProtocolJSExportWitness {
    func witness() {}
    func exported() {}
    var intermediateValue: Int { 0 }
    func notExported() {}
}

public class FixtureClassJSExportRetainer {
    public func retain() {
        _ = FixtureClassJSExport()
    }
}
