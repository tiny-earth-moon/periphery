import Foundation

public actor ItemActor {}

public class IsolatedParameterHost {
    func work() async -> Int { 1 }

    public func inheritsIsolation(isolation: isolated (any Actor)? = #isolation) async -> Int {
        await work()
    }

    public func runsOnActor(_ actor: isolated ItemActor) -> Int { 1 }

    public func labeledActor(on actor: isolated ItemActor) -> Int { 1 }

    public func defaultIsolationValue(isolation: (any Actor)? = #isolation) async -> Int {
        await work()
    }

    public func plainUnused(value: Int) -> Int { 1 }

    public func nonIsolatedActor(_ actor: ItemActor) -> Int { 1 }
}
