import Foundation

// outskirts:ignore
public class FixtureOutskirtsIgnoredClass {}

public class FixtureOutskirtsParametersClass {
    // outskirts:ignore:parameters b
    public func someFunc(a: String, b: String) {
        print(a)
    }
}
