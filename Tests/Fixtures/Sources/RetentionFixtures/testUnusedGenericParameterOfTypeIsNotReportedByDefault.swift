import Foundation

public struct FixturePhantomTagged<Tag> {
    public let raw: Int
    public init(raw: Int) {
        self.raw = raw
    }
}

public enum FixturePhantomUserTag {}
public typealias FixturePhantomUserID = FixturePhantomTagged<FixturePhantomUserTag>

public class FixturePhantomClass<Marker> {
    public init() {}
}

public enum FixturePhantomEnum<Marker> {
    case a
}

public actor FixturePhantomActor<Marker> {
    public init() {}
}
