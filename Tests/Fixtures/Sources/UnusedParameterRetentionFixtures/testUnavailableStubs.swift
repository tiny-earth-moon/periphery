import Foundation

public class UnavailableStubHost {
    @available(*, unavailable)
    public func plain(value: Int) -> Int { 0 }

    @available(*, unavailable, message: "use something else")
    public func withMessage(value: Int) -> Int { 0 }

    @available(*, unavailable, renamed: "replacement(value:)")
    public func renamedStub(value: Int) -> Int { 0 }

    @available( * ,   unavailable ,   message : "use something else" )
    public func extraWhitespace(value: Int) -> Int { 0 }

    @available(*, unavailable, message: "was available, unavailable, now gone")
    public func commasInMessage(value: Int) -> Int { 0 }

    @available(*, deprecated, message: "use something else")
    public func deprecatedOnly(value: Int) -> Int { 0 }

    public func replacement(value: Int) -> Int { value }
}
