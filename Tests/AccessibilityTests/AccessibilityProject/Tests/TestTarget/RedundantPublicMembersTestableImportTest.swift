@testable import TargetA
import XCTest

class RedundantPublicMembersTestableImportTest: XCTestCase {
    func testUsedByTestsOnly() {
        RpmPublicStruct().rpmUsedByTestsOnly()
    }
}
