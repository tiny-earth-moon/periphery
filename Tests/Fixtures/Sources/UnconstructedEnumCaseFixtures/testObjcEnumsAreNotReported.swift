import Foundation

@objc enum FixtureObjcState: Int {
    case idle
    case onlyMatched
}

public func fixtureObjcMatch() -> Bool {
    if case .onlyMatched = FixtureObjcState.idle { return true }
    return false
}
