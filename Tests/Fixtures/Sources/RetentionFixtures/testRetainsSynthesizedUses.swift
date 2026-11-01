struct FixtureStruct1210 {
    let id: Int
    let name: String
    let nested: FixtureStruct1211
    var computed: Int { 1 }
}

struct FixtureStruct1211 {
    let value: Int
}

struct FixtureStruct1212 {
    let described: Int
}

struct FixtureStruct1213 {
    let interpolated: Int
}

struct FixtureStruct1214 {
    let annotated: Int
}

struct FixtureStruct1215: CustomStringConvertible {
    let custom: Int
    var description: String { "custom" }
}

final class FixtureClass1216 {
    let printed: Int

    init(printed: Int) {
        self.printed = printed
    }
}

final class FixtureClass1217 {
    let dumped: Int

    init(dumped: Int) {
        self.dumped = dumped
    }
}

struct FixtureStruct1218 {
    let unused: Int
}

public enum FixtureEnum1219 {
    public static func run() -> String {
        print(FixtureStruct1210(id: 1, name: "a", nested: FixtureStruct1211(value: 1)))

        let described = FixtureStruct1212(described: 1)
        _ = String(describing: described)

        let annotated: FixtureStruct1214 = .init(annotated: 1)
        debugPrint(annotated)

        print(FixtureStruct1215(custom: 1))
        print(FixtureClass1216(printed: 1))
        dump(FixtureClass1217(dumped: 1))
        _ = FixtureStruct1218(unused: 1)

        return "\(FixtureStruct1213(interpolated: 1))"
    }
}
