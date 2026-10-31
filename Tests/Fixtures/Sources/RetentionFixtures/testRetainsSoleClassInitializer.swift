import Foundation

public class FixtureClassSoleInitializer {
    let value: Int

    init(value: Int) {
        self.value = value
    }
}

public class FixtureClassSecondInitializer {
    let value: Int

    init(value: Int) {
        self.value = value
    }

    init(other: Int) {
        value = other
    }
}

public struct FixtureStructSoleInitializer {
    let value: Int

    init(value: Int) {
        self.value = value
    }
}
