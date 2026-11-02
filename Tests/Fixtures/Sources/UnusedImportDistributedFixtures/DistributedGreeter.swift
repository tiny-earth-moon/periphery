import Distributed

public distributed actor DistributedGreeter {
    public typealias ActorSystem = LocalTestingDistributedActorSystem

    public distributed func hello() -> Int { 1 }
}
