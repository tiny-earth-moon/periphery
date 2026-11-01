import Foundation

@propertyWrapper
public struct FixtureUnassignedOptionalWrapper<Value> {
    public var wrappedValue: Value?

    public init() {}
}

public struct FixtureUnassignedOptionalDecodableStruct: Decodable {
    var decoded: Int?

    public func read() {
        print(decoded as Any)
    }
}

public class FixtureUnassignedOptionalDecodableClass: Decodable {
    var decoded: Int?

    public func read() {
        print(decoded as Any)
    }
}

public class FixtureUnassignedOptionalCoding: NSObject, NSSecureCoding {
    public static var supportsSecureCoding: Bool { true }

    var decoded: Int?

    public required init?(coder _: NSCoder) {
        super.init()
    }

    public func encode(with _: NSCoder) {}

    public func read() {
        print(decoded as Any)
    }
}

public class FixtureUnassignedOptionalRuntime {
    weak var weakReference: AnyObject?
    @FixtureUnassignedOptionalWrapper var wrapped: Int?

    public init() {}

    public func read() {
        print(weakReference as Any)
        print(wrapped as Any)
    }
}

#if canImport(AppKit)
    import AppKit

    public class FixtureUnassignedOptionalInterfaceBuilder: NSObject {
        @IBOutlet var outlet: NSView!
        @objc var objcProperty: NSObject?
        @objc dynamic var dynamicProperty: NSObject?

        public func read() {
            print(outlet as Any)
            print(objcProperty as Any)
            print(dynamicProperty as Any)
        }
    }
#endif
