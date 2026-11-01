@propertyWrapper
struct FixtureStruct1300Wrapper {
    var wrappedValue: Int
}

public class FixtureClass1301 {
    @FixtureStruct1300Wrapper var wrapped: Int = 0
    var plain: Int = 0

    @discardableResult func tagged() -> Int { 1 }
    func untagged() {}
}
