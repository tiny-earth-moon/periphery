import SwiftUI

struct TextFieldStyleFixture: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration.padding(4)
    }

    func unusedHelper() {}
}

struct ExtensionTextFieldStyleFixture {}

extension ExtensionTextFieldStyleFixture: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration.padding(6)
    }
}

struct UnusedTextFieldStyleFixture: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration.padding(8)
    }
}

struct NonStyleFixture {
    func _body(configuration: Int) -> Int { configuration }
}

public struct TextFieldStyleFixtureRoot: View {
    @State private var text = ""

    public var body: some View {
        VStack {
            TextField("Name", text: $text).textFieldStyle(TextFieldStyleFixture())
            TextField("Name", text: $text).textFieldStyle(ExtensionTextFieldStyleFixture())
        }
    }
}
