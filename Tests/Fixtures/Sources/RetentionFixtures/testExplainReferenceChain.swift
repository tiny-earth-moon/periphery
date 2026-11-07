import Foundation

public class ExplainChainRoot {
    public func start() {
        ExplainChainMiddle().step()
    }
}

class ExplainChainMiddle {
    func step() {
        ExplainChainLeaf().finish()
    }
}

class ExplainChainLeaf {
    func finish() {}
}
