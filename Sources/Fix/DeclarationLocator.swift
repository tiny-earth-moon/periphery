import SourceGraph
import SwiftSyntax

/// Walks up from the token at a result's position to the declaration it names, and checks the name and the kind.
enum DeclarationLocator {
    /// The declaration whose name is the token, provided its name and kind match the result.
    static func declaration(named token: TokenSyntax, name: String, kind: Declaration.Kind?) -> DeclSyntax? {
        guard let decl = token.ancestorOrSelf(mapping: { $0.as(DeclSyntax.self) }),
              isName(token, of: decl, name: name)
        else { return nil }

        if let kind, !kinds(of: decl).contains(kind) {
            return nil
        }
        return decl
    }

    // MARK: - Private

    private static let functionKinds: Set<Declaration.Kind> = [
        .functionFree, .functionMethodClass, .functionMethodInstance, .functionMethodStatic,
        .functionOperator, .functionOperatorInfix, .functionOperatorPostfix, .functionOperatorPrefix,
    ]
    private static let variableKinds: Set<Declaration.Kind> = [.varGlobal, .varInstance, .varStatic, .varClass, .varLocal]
    private static let extensionKinds: Set<Declaration.Kind> = [
        .extension, .extensionClass, .extensionEnum, .extensionProtocol, .extensionStruct,
    ]

    private static func kinds(of decl: DeclSyntax) -> Set<Declaration.Kind> {
        switch decl.kind {
        case .functionDecl: functionKinds
        case .initializerDecl: [.functionConstructor]
        case .deinitializerDecl: [.functionDestructor]
        case .subscriptDecl: [.functionSubscript]
        case .variableDecl: variableKinds
        case .classDecl, .actorDecl: [.class]
        case .structDecl: [.struct]
        case .enumDecl: [.enum]
        case .protocolDecl: [.protocol]
        case .typeAliasDecl: [.typealias]
        case .associatedTypeDecl: [.associatedtype]
        case .macroDecl: [.macro]
        case .enumCaseDecl: [.enumelement]
        case .precedenceGroupDecl: [.precedenceGroup]
        case .extensionDecl: extensionKinds
        default: []
        }
    }

    private static func isName(_ token: TokenSyntax, of decl: DeclSyntax, name: String) -> Bool {
        let baseName = name.split(separator: "(", maxSplits: 1).first.map(String.init) ?? name
        let text = token.text.trimmingBackticks

        if let function = decl.as(FunctionDeclSyntax.self) {
            return function.name.id == token.id && text == baseName
        }
        if let initializer = decl.as(InitializerDeclSyntax.self) {
            return initializer.initKeyword.id == token.id && baseName == "init"
        }
        if let deinitializer = decl.as(DeinitializerDeclSyntax.self) {
            return deinitializer.deinitKeyword.id == token.id && baseName == "deinit"
        }
        if let subscriptDecl = decl.as(SubscriptDeclSyntax.self) {
            return subscriptDecl.subscriptKeyword.id == token.id && baseName == "subscript"
        }
        if let variable = decl.as(VariableDeclSyntax.self) {
            return text == name && variable.bindings.contains { binding in
                binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.id == token.id
            }
        }
        if let enumCase = decl.as(EnumCaseDeclSyntax.self) {
            return text == baseName && enumCase.elements.contains { $0.name.id == token.id }
        }
        if let extensionDecl = decl.as(ExtensionDeclSyntax.self) {
            let type = extensionDecl.extendedType
            let isInType = type.positionAfterSkippingLeadingTrivia <= token.positionAfterSkippingLeadingTrivia
                && token.endPositionBeforeTrailingTrivia <= type.endPositionBeforeTrailingTrivia
            return isInType && (type.trimmedDescription == name || text == name)
        }
        if let named = decl.asProtocol(NamedDeclSyntax.self) {
            return named.name.id == token.id && text == baseName
        }
        return false
    }
}

extension String {
    var trimmingBackticks: String {
        hasPrefix("`") && hasSuffix("`") && count >= 2 ? String(dropFirst().dropLast()) : self
    }
}
