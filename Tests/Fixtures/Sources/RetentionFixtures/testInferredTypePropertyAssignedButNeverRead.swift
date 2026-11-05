#if canImport(Combine)
import Combine
#endif
import Foundation

final class FixtureClass1500Reference {}

public class FixtureClass1500 {
    struct CustomType {}

    var inferredLiteral = 0
    var annotatedLiteral: Int = 0
    var inferredConstructor = FixtureClass1500Reference()
    var inferredRead = 0
    static var inferredStatic = ""
    lazy var inferredLazy = 0
    lazy var annotatedLazy: Int = 0
    var inferredComputed: Int { 0 }
    var inferredObserved = 0 {
        didSet { print("observed") }
    }
    var inferredWillSet = 0 {
        willSet { print("observed") }
    }
    @FixtureStruct1500Wrapper var inferredWrapped = 0
    var inferredRetainedCustom = CustomType()
    var inferredRetainedQualified = 1.0

    #if canImport(Combine)
    var inferredAnyCancellable = CurrentValueSubject<Bool, Never>(true).sink { _ in }
    var inferredAnyCancellableSet = Set<AnyCancellable>()
    #endif

    public func someFunc() {
        inferredLiteral = 1
        annotatedLiteral = 1
        inferredConstructor = FixtureClass1500Reference()
        inferredRead = 1
        print(inferredRead)
        FixtureClass1500.inferredStatic = "x"
        inferredLazy = 1
        annotatedLazy = 1
        inferredObserved = 1
        inferredWillSet = 1
        inferredWrapped = 1
        inferredRetainedCustom = CustomType()
        inferredRetainedQualified = 2.0

        #if canImport(Combine)
        inferredAnyCancellable = CurrentValueSubject<Bool, Never>(false).sink { _ in }
        inferredAnyCancellableSet = []
        #endif
    }
}

@propertyWrapper
struct FixtureStruct1500Wrapper<Value> {
    var wrappedValue: Value
}
