enum Tool {
    static func helper() -> Int {
        1
    }

    static func unusedHelper() {}
}

@main
extension Tool {
    static func main() {
        print(helper())
    }
}
