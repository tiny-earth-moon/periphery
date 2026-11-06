public class PublicLibClass {}

public func publicLibFunction() {}

public enum PublicLibEnum {
    case first
}

open class OpenLibClass {
    // swiftformat:disable:next unusedArguments
    open func overridable(_ value: Int) {}
}

public func publicLibEntryPoint() {
    publicLibHelper()
}

public func publicLibHelper() {}

func internalLibFunction() {}
