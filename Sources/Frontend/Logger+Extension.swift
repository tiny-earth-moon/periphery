import Configuration
import Logger

public extension Logger {
    @inlinable
    init(configuration: Configuration, messagesToStderr: Bool = false) {
        let colorMode: LoggerColorMode = switch configuration.color {
        case .auto: .auto
        case .always: .always
        case .never: .never
        }
        self.init(
            quiet: configuration.quiet,
            verbose: configuration.verbose,
            colorMode: colorMode,
            messagesToStderr: messagesToStderr || !configuration.outputFormat.supportsAuxiliaryOutput
        )
    }
}
