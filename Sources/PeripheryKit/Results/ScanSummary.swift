import Foundation
import Logger
import SystemPackage

/// What a scan amounts to: the number of results of each kind, the files that can be removed whole and an estimate
/// of the lines that removing the reported code would delete.
public struct ScanSummary: Equatable {
    public struct UnusedFile: Equatable {
        public let path: FilePath
        public let lineCount: Int
    }

    /// The number of results, the conformances of a redundant protocol not counted apart.
    public let resultCount: Int
    /// The number of results of each annotation, keyed by its name in the `hints` of the `json` format.
    public let countsByAnnotation: [String: Int]
    /// The lines of the unused declarations and empty extensions, attached doc comments and attributes included,
    /// each line counted once however many reported declarations cover it.
    public let removableLineCount: Int
    /// The Swift files whose every top-level declaration, imports excepted, is reported as unused, sorted by path.
    public let unusedFiles: [UnusedFile]
}

struct ScanSummaryBuilder {
    let logger: Logger

    func build(_ results: [ScanResult], annotationName: (ScanResult.Annotation) -> String) -> ScanSummary {
        var countsByAnnotation: [String: Int] = [:]
        var removedByFile: [FilePath: [ScanResult]] = [:]

        for result in results {
            countsByAnnotation[annotationName(result.annotation), default: 0] += 1

            let file = result.declaration.location.file.path
            if result.annotation.removesCode, file.extension == "swift" {
                removedByFile[file, default: []].append(result)
            }
        }

        var removableLineCount = 0
        var unusedFiles: [ScanSummary.UnusedFile] = []

        for (file, removed) in removedByFile.sorted(by: { $0.key.string < $1.key.string }) {
            guard let declarations = declarations(in: file) else { continue }

            var reportedElements: [Int: Set<Int>] = [:]
            for result in removed {
                let location = result.declaration.location
                let position = SourceFileDeclarations.Position(line: location.line, column: location.column)
                if let (span, element) = declarations.elementsByPosition[position] {
                    reportedElements[span, default: []].insert(element)
                }
            }

            let removedSpans = Set(reportedElements.compactMap { span, elements in
                elements.count == declarations.spans[span].elementCount ? span : nil
            })
            let lines = removedSpans.reduce(into: Set<Int>()) { lines, span in
                lines.formUnion(declarations.spans[span].lines)
            }
            removableLineCount += lines.count

            if !declarations.hasOtherTopLevelCode, !declarations.topLevelSpans.isEmpty, declarations.topLevelSpans.allSatisfy(removedSpans.contains) {
                unusedFiles.append(.init(path: file, lineCount: declarations.lineCount))
            }
        }

        return ScanSummary(
            resultCount: results.count,
            countsByAnnotation: countsByAnnotation,
            removableLineCount: removableLineCount,
            unusedFiles: unusedFiles
        )
    }

    // MARK: - Private

    private func declarations(in file: FilePath) -> SourceFileDeclarations? {
        do {
            return try SourceFileDeclarations(source: String(contentsOfFile: file.string, encoding: .utf8))
        } catch {
            logger.warn("The summary leaves out \(file.string), which could not be read: \(error.localizedDescription)")
            return nil
        }
    }
}

private extension ScanResult.Annotation {
    /// Whether acting on the result deletes code: accessibility, `final` and assign-only results only change it.
    var removesCode: Bool {
        switch self {
        case .unused, .emptyExtension:
            true
        default:
            false
        }
    }
}
