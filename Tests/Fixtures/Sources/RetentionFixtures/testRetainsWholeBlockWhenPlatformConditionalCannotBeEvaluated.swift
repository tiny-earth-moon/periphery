import Foundation

struct FixtureUnevaluatedFlagAlpha { func unevaluatedFlag() {} }
struct FixtureUnevaluatedFlagBeta { func unevaluatedFlag() {} }
struct FixtureUnevaluatedImportAlpha { func unevaluatedImport() {} }
struct FixtureUnevaluatedImportBeta { func unevaluatedImport() {} }
struct FixtureUnevaluatedVersionAlpha { func unevaluatedVersion() {} }
struct FixtureUnevaluatedVersionBeta { func unevaluatedVersion() {} }
struct FixtureUnevaluatedNestedAlpha { func unevaluatedNested() {} }
struct FixtureUnevaluatedNestedBeta { func unevaluatedNested() {} }
struct FixtureUnevaluatedInnerAlpha { func unevaluatedInner() {} }
struct FixtureUnevaluatedInnerBeta { func unevaluatedInner() {} }

public class FixtureUnevaluatedUser {
    public func entry() {
        #if FIXTURE_UNDEFINED_FLAG || os(macOS) || os(Linux)
        FixtureUnevaluatedFlagAlpha().unevaluatedFlag()
        #endif

        #if canImport(Foundation)
        FixtureUnevaluatedImportAlpha().unevaluatedImport()
        #endif

        #if (os(macOS) || os(Linux)) && swift(>=5.0)
        FixtureUnevaluatedVersionAlpha().unevaluatedVersion()
        #endif

        #if FIXTURE_UNDEFINED_FLAG
        #if os(macOS) || os(Linux)
        FixtureUnevaluatedNestedAlpha().unevaluatedNested()
        #endif
        #endif

        #if os(macOS) || os(Linux)
        #if arch(arm64) || arch(x86_64)
        FixtureUnevaluatedInnerAlpha().unevaluatedInner()
        #endif
        #endif

        _ = FixtureUnevaluatedFlagBeta()
        _ = FixtureUnevaluatedImportBeta()
        _ = FixtureUnevaluatedVersionBeta()
        _ = FixtureUnevaluatedNestedBeta()
        _ = FixtureUnevaluatedInnerBeta()
    }
}
