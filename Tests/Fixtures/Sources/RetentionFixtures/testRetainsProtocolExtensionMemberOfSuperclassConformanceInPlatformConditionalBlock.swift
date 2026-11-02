protocol FixtureTypesP12 {}

extension FixtureTypesP12 {
    func typesSuperExt() {}
}

public class FixtureTypesBase12 {}

extension FixtureTypesBase12: FixtureTypesP12 {}

public class FixtureTypesSub12: FixtureTypesBase12 {}

public struct FixtureTypesDistractor12 {
    func typesSuperExt() {}
}

public class FixtureTypesUser12 {
    public func entry() {
        #if canImport(UIKit)
        FixtureTypesSub12().typesSuperExt()
        #endif
    }
}
