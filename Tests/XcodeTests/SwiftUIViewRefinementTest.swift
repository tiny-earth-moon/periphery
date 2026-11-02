import Configuration
@testable import TestShared

final class SwiftUIViewRefinementTest: XcodeSourceGraphTestCase {
    override static func setUp() {
        super.setUp()

        let configuration = Configuration()
        configuration.schemes = ["SwiftUIProject"]

        build(projectPath: SwiftUIProjectPath, configuration: configuration)
        index(configuration: configuration)
    }

    func testRetainsPreviewOnlyCodeOfViewConformingThroughRefinedProtocol() {
        assertReferenced(.struct("LiveRefinedScreen"))
        assertReferenced(.enum("LiveRefinedPreviewData")) {
            self.assertReferenced(.varStatic("title"))
        }
    }

    func testDoesNotRetainCodeOfPreviewOfUnusedViewConformingThroughRefinedProtocol() {
        assertNotReferenced(.struct("DeadRefinedScreen"))
        assertNotReferenced(.enum("DeadRefinedPreviewData"))
    }
}
