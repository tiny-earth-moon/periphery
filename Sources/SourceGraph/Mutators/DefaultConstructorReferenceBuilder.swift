import Configuration
import Foundation
import Shared

final class DefaultConstructorReferenceBuilder: SourceGraphMutator {
    private let graph: SourceGraph

    required init(graph: SourceGraph, configuration _: Configuration, swiftVersion _: SwiftVersion) {
        self.graph = graph
    }

    func mutate() {
        referenceDefaultConstructors()
        referenceSoleClassConstructors()
        referenceDestructors()
    }

    // MARK: - Private

    private func referenceDefaultConstructors() {
        let defaultConstructors = graph.declarations(ofKind: .functionConstructor).filter {
            // Some initializers are referenced internally, e.g by JSONEncoder/Decoder so we need
            // to assume they are referenced.
            $0.name == "init()" || $0.isImplicit
        }

        for constructor in defaultConstructors {
            if let parent = constructor.parent {
                for usr in constructor.usrs {
                    let reference = Reference(
                        name: constructor.name,
                        kind: .normal,
                        declarationKind: .functionConstructor,
                        usr: usr,
                        location: parent.location
                    )
                    reference.parent = parent
                    graph.add(reference, from: parent)
                }
            }
        }
    }

    /// Removing the only initializer of a class would leave it without any initializer, which
    /// fails to compile if it has stored properties without default values.
    private func referenceSoleClassConstructors() {
        for classDecl in graph.declarations(ofKind: .class) {
            let constructors = classDecl.declarations.filter { $0.kind == .functionConstructor }
            guard constructors.count == 1, let constructor = constructors.first, !constructor.isImplicit else { continue }

            for usr in constructor.usrs {
                let reference = Reference(
                    name: constructor.name,
                    kind: .normal,
                    declarationKind: .functionConstructor,
                    usr: usr,
                    location: classDecl.location
                )
                reference.parent = classDecl
                graph.add(reference, from: classDecl)
            }
        }
    }

    private func referenceDestructors() {
        for destructor in graph.declarations(ofKind: .functionDestructor) {
            if let parent = destructor.parent {
                for usr in destructor.usrs {
                    let reference = Reference(
                        name: destructor.name,
                        kind: .normal,
                        declarationKind: .functionDestructor,
                        usr: usr,
                        location: parent.location
                    )
                    reference.parent = parent
                    graph.add(reference, from: parent)
                }
            }
        }
    }
}
