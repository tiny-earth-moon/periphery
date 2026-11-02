import SwiftUI

extension View {
    func fixtureSyntax15Style() -> some View { self }
    func fixtureSyntax15Other() -> some View { self }
}

struct FixtureSyntax15Decoy {
    func fixtureSyntax15Style() {}
    func fixtureSyntax15Other() {}
}

struct FixtureSyntax15Row: View {
    var body: some View { Text("row") }
}

public struct FixtureSyntax15Screen: View {
    public init() {}

    public var body: some View {
        VStack {
            FixtureSyntax15Row()
            #if os(iOS)
                .fixtureSyntax15Style()
            #endif
            #if os(iOS)
            FixtureSyntax15Row().fixtureSyntax15Other()
            #endif
        }
        .onAppear { _ = FixtureSyntax15Decoy() }
    }
}
