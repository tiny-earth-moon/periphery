import Configuration
import Logger
import PeripheryKit

/// Checks and adjustments applied to the configuration before the scan starts, so that a mistake costs
/// no build, indexing or analysis.
enum ScanPreflight {
    /// Forces `relativeResults` for the output formats that only work with paths relative to the project root.
    static func applyOutputFormatRequirements(to configuration: Configuration, logger: Logger) {
        guard configuration.outputFormat.requiresRelativePaths, !configuration.relativeResults else { return }

        configuration.relativeResults = true
        logger.contextualized(with: "configuration").debug("'\(configuration.outputFormat.rawValue)' output requires relative paths, enabling '--relative-results'")
    }
}
