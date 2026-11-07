import ArgumentParser
import Configuration
import Fix
import Foundation
import Logger
import PeripheryKit
import ProjectDrivers
import Shared

struct FixCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fix",
        abstract: "Scan, then apply the syntax-only fixes: print a unified diff, or write the files with --apply",
        discussion: "Takes every option of the scan command. Rules: \(FixRule.allCases.filter { !$0.isAggressive }.map(\.rawValue).joined(separator: ", ")); with --aggressive: \(FixRule.allCases.filter(\.isAggressive).map(\.rawValue).joined(separator: ", ")). Rules whose analysis is opt-in only apply when the analysis is enabled."
    )

    @Flag(help: "Write the fixes to the files atomically instead of printing a unified diff")
    var apply: Bool = false

    @Flag(help: "With --apply, rebuild the project after writing the fixes, and restore every original file if the build fails")
    var verify: Bool = false

    @Flag(help: "Also apply the tier-2 rules, which change behavior: add final to the classes that the open/final analysis reports")
    var aggressive: Bool = false

    @Option(name: .customLong("rule"), help: "Only apply the given rule; repeat to apply several")
    var rules: [FixRule] = []

    @Option(name: .customLong("include"), help: "Only fix the files that match the glob; repeat to give several")
    var includes: [String] = []

    @Flag(help: "Also fix files that have uncommitted changes, or that are not in a git repository")
    var allowDirty: Bool = false

    @OptionGroup
    var scan: ScanCommand

    func validate() throws {
        if scan.projectOptions.setup {
            throw ValidationError("'--setup' cannot be used with 'fix'")
        }
        if scan.baselineOptions.writeBaseline != nil || scan.baselineOptions.pruneBaseline == true {
            throw ValidationError("'fix' does not write baselines, run 'scan' for '--write-baseline' and '--prune-baseline'")
        }
        if scan.resultsOptions.writeResults != nil {
            throw ValidationError("'fix' does not write results, run 'scan' for '--write-results'")
        }
        if verify, !apply {
            throw ValidationError("'--verify' rebuilds the project after writing the fixes, it requires '--apply'")
        }
        if !aggressive, let rule = rules.first(where: \.isAggressive) {
            throw ValidationError("'\(rule.rawValue)' is a tier-2 rule, it requires '--aggressive'")
        }
    }

    func run() throws {
        let prepared = try scan.prepareScan(messagesToStderr: true)
        let configuration = prepared.configuration
        let logger = prepared.logger
        if verify {
            try validateVerifiableBuild(configuration: configuration, project: prepared.project)
        }

        let scanStartedAt = Date()
        let output = try Scan(configuration: configuration, logger: logger, swiftVersion: prepared.swiftVersion)
            .perform(project: prepared.project)
        let filtered = try OutputDeclarationFilter(configuration: configuration, logger: logger)
            .filter(output.results, with: prepared.baseline)
        let reported = try ChangedSinceFilter(configuration: configuration, shell: prepared.shell, logger: logger)
            .filter(filtered)

        let targets = selectTargets(from: reported, configuration: configuration)
        let workingTree: WorkingTreeState = try allowDirty ? .ignored : GitWorkingTree.state(at: configuration.projectRoot)
        let indexDates = IndexDates(scanStartedAt: scanStartedAt, unitDates: output.unitDates)
        let plan = FixPlanner(workingTree: workingTree, indexDates: indexDates, isIndexExcluded: configuration.isIndexExcluded)
            .plan(targets)

        if apply {
            try FixWriter.apply(plan)
        } else {
            let diff = plan.diff(relativeTo: configuration.projectRoot)
            if !diff.isEmpty {
                logger.output(String(diff.dropLast()))
            }
        }

        logger.info(plan.summary(relativeTo: configuration.projectRoot, applying: apply))
        if verify, !plan.changes.isEmpty {
            try verifyBuild(of: plan, driver: output.driver, configuration: configuration, logger: logger)
        }
    }

    // MARK: - Private

    /// `--verify` rebuilds with the driver of the scan, so the scan must build the project itself.
    private func validateVerifiableBuild(configuration: Configuration, project: Project) throws {
        if configuration.skipBuild || !configuration.indexStorePath.isEmpty {
            throw PeripheryError.usageError("'--verify' rebuilds the project after writing the fixes, but the build is skipped ('--skip-build' or '--index-store-path'), so the fixes could not be verified. Remove these options, or apply without '--verify' and build yourself.")
        }
        if case .generic = project.kind {
            throw PeripheryError.usageError("'--verify' rebuilds the project after writing the fixes, but a project described by '--generic-project-config' is built outside outskirts, so the fixes could not be verified. Apply without '--verify' and build yourself.")
        }
    }

    /// Rebuilds the project; when the build fails, writes back every original buffer and fails.
    private func verifyBuild(of plan: FixPlan, driver: ProjectDriver, configuration: Configuration, logger: Logger) throws {
        // The scan already cleaned the build if asked to: only the fixed files need to be rebuilt.
        configuration.cleanBuild = false
        do {
            try driver.build()
        } catch {
            let restoration = FixWriter.restore(plan)
            logger.error("The build failed after the fixes were applied:\n\(error.localizedDescription)")
            throw PeripheryError.usageError(restoration.summary(relativeTo: configuration.projectRoot, changeCount: plan.changes.count))
        }
        logger.info("The project builds with the fixes.")
    }

    private func selectTargets(from results: [ScanResult], configuration: Configuration) -> [FixTarget] {
        let selectedRules = rules.isEmpty ? Set(FixRule.allCases.filter { aggressive || !$0.isAggressive }) : Set(rules)
        let includeMatchers = configuration.buildFilenameMatchers(with: includes)

        return results.compactMap(FixTarget.init(result:)).filter { target in
            selectedRules.contains(target.rule)
                && target.rule.isEnabled(in: configuration)
                && (includeMatchers.isEmpty || includeMatchers.anyMatch(filename: target.file.string))
        }
    }
}

extension FixRule: ExpressibleByArgument {}
