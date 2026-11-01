public struct FixtureStruct1200 {
    let path: String
    let name: String
}

public final class FixtureClass1201 {
    var identifier: String

    init(identifier: String) {
        self.identifier = identifier
    }
}

public enum FixtureEnum1202 {
    public static func thingsByPath(_ things: [FixtureStruct1200]) -> [String] {
        var thingByPath = [String: FixtureStruct1200]()
        for thing in things {
            thingByPath[thing.path] = thing
        }
        return Array(thingByPath.keys)
    }

    public static func namesByIdentifier(_ object: FixtureClass1201) -> [String] {
        var names: [String: String] = [:]
        names[object.identifier] = FixtureStruct1200(path: "", name: "").name
        return Array(names.keys)
    }
}

public class FixtureClass1203 {
    private let key = "the-key"

    public func run() -> Int {
        var dictionary: [String: Any] = [:]
        dictionary[key] = 42
        return dictionary.count
    }
}
