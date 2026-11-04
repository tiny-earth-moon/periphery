#if os(macOS)
    @testable import PeripheryKit
    import SourceGraph
    import SystemPackage
    @testable import TestShared
    import XCTest

    final class MetalFunctionTest: FixtureSourceGraphTestCase {
        private let fixtureRoot = FixturesProjectPath.appending("Sources/MetalFunctionFixtures")

        func testDetectsUnusedMetalFunctions() {
            let results = analyze(retainPublic: true, detectUnusedMetalFunctions: true, projectRoot: fixtureRoot) {
                assertReferenced(.metalFunction("fixtureUsedKernel"))
                assertReferenced(.metalFunction("fixtureSpecializedVertex"))
                assertReferenced(.metalFunction("fixtureDescriptorVisible"))
                assertNotReferenced(.metalFunction("fixtureUnusedFragment"))
                assertNotReferenced(.metalFunction("fixtureUnusedVisible"))
                assertNotReferenced(.metalFunction("fixtureUnusedStitchable"))
                assertNotReferenced(.metalFunction("fixtureDynamicKernel"))
                assertNotIndexed(.metalFunction("fixtureHelper"))
                assertNotIndexed(.metalFunction("fixtureCommentedKernel"))
                assertNotIndexed(.metalFunction("fixtureConditionalKernel"))
            }

            XCTAssertEqual(unusedMetalFunctions(results), [
                "fixtureDynamicKernel", "fixtureUnusedFragment", "fixtureUnusedStitchable", "fixtureUnusedVisible",
            ])

            // A function of a conditional block is known: naming it is not reported.
            let missing = results.filter {
                if case .missingMetalFunction = $0.annotation {
                    true
                } else {
                    false
                }
            }
            XCTAssertEqual(missing.map(\.declaration.name), ["fixtureMissingFunction"])
            XCTAssertEqual(missing.first?.declaration.location.file.path, testFixturePath)
            XCTAssertEqual(missing.first?.declaration.location.line, 7)
            XCTAssertEqual(missing.first?.declaration.usrs, ["metal-missing:testDetectsUnusedMetalFunctions.swift:fixtureMissingFunction"])
        }

        func testRetainsEveryFunctionForANonLiteralName() {
            let results = analyze(retainPublic: true, detectUnusedMetalFunctions: true, projectRoot: fixtureRoot) {
                assertReferenced(.metalFunction("fixtureUnusedFragment"))
                assertReferenced(.metalFunction("fixtureDynamicKernel"))
            }

            XCTAssertEqual(unusedMetalFunctions(results), [])
            XCTAssertFalse(results.contains {
                if case .missingMetalFunction = $0.annotation {
                    true
                } else {
                    false
                }
            })
        }

        func testDoesNotReportMissingFunctionsWhenALibraryIsCompiledAtRunTime() {
            let results = analyze(retainPublic: true, detectUnusedMetalFunctions: true, projectRoot: fixtureRoot) {
                assertNotReferenced(.metalFunction("fixtureUsedKernel"))
                assertNotReferenced(.metalFunction("fixtureUnusedFragment"))
            }

            XCTAssertFalse(results.contains {
                if case .missingMetalFunction = $0.annotation {
                    true
                } else {
                    false
                }
            })
            XCTAssertTrue(unusedMetalFunctions(results).contains("fixtureUsedKernel"))
            XCTAssertTrue(unusedMetalFunctions(results).contains("fixtureUnusedFragment"))
        }

        func testDetectsNothingWithoutTheOption() {
            let results = analyze(retainPublic: true, projectRoot: fixtureRoot) {
                assertNotIndexed(.metalFunction("fixtureUnusedFragment"))
            }

            XCTAssertFalse(results.contains { $0.declaration.kind == .metalFunction })
        }

        // MARK: - Private

        private func unusedMetalFunctions(_ results: [ScanResult]) -> [String] {
            results
                .filter { $0.declaration.kind == .metalFunction && {
                    if case .unused = $0 {
                        true
                    } else {
                        false
                    }
                }($0.annotation) }
                .map(\.declaration.name)
                .sorted()
        }
    }
#endif
