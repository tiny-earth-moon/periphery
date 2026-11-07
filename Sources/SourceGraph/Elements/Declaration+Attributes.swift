extension Declaration {
    func hasAttribute(named name: String) -> Bool {
        attributes.contains { $0.name == name }
    }

    func hasAttribute(in names: Set<String>) -> Bool {
        attributes.contains { names.contains($0.name) }
    }
}
