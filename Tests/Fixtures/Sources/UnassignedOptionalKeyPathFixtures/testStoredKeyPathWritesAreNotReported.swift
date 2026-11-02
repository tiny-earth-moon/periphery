public class FixtureStoredKeyPathTarget {
    var direct: Int?
    var viaFunction: Int?
    var viaStored: Int?
    var neverAssigned: Int?

    public init() {}
}

private func fixtureStoredKeyPathSet<Root>(_ root: Root, _ keyPath: ReferenceWritableKeyPath<Root, Int?>, to value: Int) {
    root[keyPath: keyPath] = value
}

public func fixtureStoredKeyPathRun() {
    let target = FixtureStoredKeyPathTarget()
    target[keyPath: \.direct] = 1
    fixtureStoredKeyPathSet(target, \.viaFunction, to: 2)
    let stored: ReferenceWritableKeyPath<FixtureStoredKeyPathTarget, Int?> = \.viaStored
    target[keyPath: stored] = 3
    print(target.direct as Any, target.viaFunction as Any, target.viaStored as Any, target.neverAssigned as Any)
}
