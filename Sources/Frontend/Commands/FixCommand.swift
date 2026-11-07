import ArgumentParser
import Configuration
import Fix
import Foundation
import PeripheryKit
import Shared

struct FixCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fix",
        abstract: "Scan, then apply the syntax-only fixes: print a unified diff, or write the files with --apply",
        discussion: "Takes every option of the scan command. Rules: \(FixRule.allCases.map(\.rawValue).joined(separator: ", ")). Rules whose analysis is opt-in only apply when the analysis is enabled."
    )

    @Flag(help: "Write the fixes to the files atomically instead of printing a unified diff")
    var apply: Bool = false

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
    }

    func run() throws {
        let prepared = try scan.prepareScan(messagesToStderr: true)
        let configuration = prepared.configuration
        let logger = prepared.logger

        let indexedAt = Date()
        let output = try Scan(configuration: configuration, logger: logger, swiftVersion: prepared.swiftVersion)
            .perform(project: prepared.project)
        let filtered = try OutputDeclarationFilter(configuration: configuration, logger: logger)
            .filter(output.results, with: prepared.baseline)
        let reported = try ChangedSinceFilter(configuration: configuration, shell: prepared.shell, logger: logger)
            .filter(filtered)

        let targets = selectTargets(from: reported, configuration: configuration)
        let workingTree: WorkingTreeState = try allowDirty ? .ignored : GitWorkingTree.state(at: configuration.projectRoot)
        let plan = FixPlanner(workingTree: workingTree, indexedAt: indexedAt, isIndexExcluded: configuration.isIndexExcluded)
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
    }

    // MARK: - Private

    private func selectTargets(from results: [ScanResult], configuration: Configuration) -> [FixTarget] {
        let selectedRules = rules.isEmpty ? Set(FixRule.allCases) : Set(rules)
        let includeMatchers = configuration.buildFilenameMatchers(with: includes)

        return results.compactMap(FixTarget.init(result:)).filter { target in
            selectedRules.contains(target.rule)
                && target.rule.isEnabled(in: configuration)
                && (includeMatchers.isEmpty || includeMatchers.anyMatch(filename: target.file.string))
        }
    }
}

extension FixRule: ExpressibleByArgument {}
