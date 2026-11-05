protocol FixtureProtocol223Memberless {}

struct FixtureStruct223Memberless: FixtureProtocol223Memberless {}

extension FixtureProtocol223Memberless where Self == FixtureStruct223Memberless {}
