enum FixtureSynthesizedDecodableState: Decodable {
    case idle
    case onlyMatched
}

enum FixtureCustomDecodableState: Decodable {
    case idle
    case onlyMatched

    init(from _: Decoder) throws {
        self = .idle
    }
}

enum FixtureCodableState: Codable {
    case idle
    case onlyMatched(Int)
}

public func fixtureDecodableMatch() -> Bool {
    if case .onlyMatched = FixtureSynthesizedDecodableState.idle { return true }
    if case .onlyMatched = FixtureCustomDecodableState.idle { return true }
    if case .onlyMatched = FixtureCodableState.idle { return true }
    return false
}
