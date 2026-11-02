func calledHelper() {}
func unusedBeforeCall() {}
calledHelper()

struct Runner {
    func go() {}
}

func unusedBeforeMethodCall() {}
Runner().go()

struct Pair {
    let first: Int
    let second: Int // periphery:ignore
}

_ = Pair(first: 0, second: 1)
