import Foundation

enum FixtureDecodedEnum: Decodable {
    case first
    case second
}

enum FixtureDecodedWithAssociatedValueEnum: Decodable {
    case first(Int)
    case second
}

enum FixtureCodableEnum: Codable {
    case first
    case second
}

enum FixtureEncodableOnlyEnum: Encodable {
    case first
    case second
}

enum FixtureNotDecodedEnum {
    case first
    case second
}

enum FixtureExplicitDecodableEnum: Decodable {
    case first
    case second

    init(from _: Decoder) throws {
        self = .first
    }
}

public func fixtureDecodableUsageRoot() throws {
    _ = try JSONDecoder().decode(FixtureDecodedEnum.self, from: Data())
    _ = try JSONDecoder().decode(FixtureDecodedWithAssociatedValueEnum.self, from: Data())
    _ = try JSONDecoder().decode(FixtureExplicitDecodableEnum.self, from: Data())
    _ = try JSONDecoder().decode(FixtureCodableEnum.self, from: Data())
    _ = FixtureEncodableOnlyEnum.self
    _ = FixtureNotDecodedEnum.self
}
