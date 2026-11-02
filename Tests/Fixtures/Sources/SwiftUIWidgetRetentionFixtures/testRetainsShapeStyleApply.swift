import SwiftUI

struct ShapeStyleFixture: ShapeStyle {
    func _apply(to shape: inout _ShapeStyle_Shape) {}

    func unusedHelper() {}
}

struct UnusedShapeStyleFixture: ShapeStyle {
    func _apply(to shape: inout _ShapeStyle_Shape) {}
}

public struct ShapeStyleFixtureRoot: View {
    public var body: some View {
        Text("Item").foregroundStyle(ShapeStyleFixture())
    }
}
