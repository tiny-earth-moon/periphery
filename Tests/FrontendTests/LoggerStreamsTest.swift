import Foundation
import Logger
import XCTest

final class LoggerStreamsTest: XCTestCase {
    func testMessagesGoToStdoutByDefault() {
        let logger = Logger(quiet: false, verbose: true, colorMode: .never)

        let (stdout, stderr) = capture {
            logger.info("info")
            logger.debug("debug")
        }

        XCTAssertEqual(stdout, "info\ndebug\n")
        XCTAssertEqual(stderr, "")
    }

    func testInfoAndDebugGoToStderrWhenMessagesAreRedirected() {
        let logger = Logger(quiet: false, verbose: true, colorMode: .never, messagesToStderr: true)

        let (stdout, stderr) = capture {
            logger.info("info")
            logger.debug("debug")
            logger.warn("warn")
        }

        XCTAssertEqual(stdout, "")
        XCTAssertEqual(stderr, "info\ndebug\nwarning: warn\n")
    }

    func testOutputAlwaysGoesToStdoutEvenWhenQuietOrRedirected() {
        let logger = Logger(quiet: true, verbose: false, colorMode: .never, messagesToStderr: true)

        let (stdout, stderr) = capture {
            logger.output("result")
            logger.info("progress")
        }

        XCTAssertEqual(stdout, "result\n")
        XCTAssertEqual(stderr, "")
    }

    // MARK: - Private

    private func capture(_ body: () -> Void) -> (stdout: String, stderr: String) {
        var stdoutText = ""
        let stderrText = redirect(STDERR_FILENO, of: stderr) {
            stdoutText = redirect(STDOUT_FILENO, of: stdout, body)
        }
        return (stdoutText, stderrText)
    }

    private func redirect(_ descriptor: Int32, of stream: UnsafeMutablePointer<FILE>, _ body: () -> Void) -> String {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("periphery-logger-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }

        fflush(stream)
        let saved = dup(descriptor)
        let target = open(file.path, O_WRONLY | O_CREAT | O_TRUNC, 0o600)
        dup2(target, descriptor)
        close(target)

        body()

        fflush(stream)
        dup2(saved, descriptor)
        close(saved)
        return (try? String(contentsOf: file, encoding: .utf8)) ?? ""
    }
}
