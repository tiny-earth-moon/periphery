import Foundation
import Shared

struct ShellMock: Shell {
    let output: String

    func exec(_: [String]) throws -> String {
        output
    }
}
