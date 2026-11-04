import Foundation

/// The Markdown pages of `docs/`, published on outskirts.dev/docs.
enum Documentation {
    /// Contents of `docs/<page>.md`.
    static func page(_ name: String) throws -> String {
        try String(contentsOfFile: ProjectRootPath.appending("docs/\(name).md").string, encoding: .utf8)
    }

    /// The anchors of the headings of a page, as GitHub and the site generator compute them.
    static func anchors(in markdown: String) -> Set<String> {
        var anchors: Set<String> = []
        var counts: [String: Int] = [:]
        var inFence = false

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                inFence.toggle()
                continue
            }
            guard !inFence, let match = line.firstMatch(of: #/^#{1,6}\s+(.*?)\s*$/#) else { continue }

            let base = slug(String(match.1))
            let count = counts[base, default: 0]
            counts[base] = count + 1
            anchors.insert(count == 0 ? base : "\(base)-\(count)")
        }

        return anchors
    }

    /// GitHub's heading slug: link targets, code and emphasis markers dropped, lowercase, punctuation removed
    /// except `-` and `_`, whitespace replaced by `-`.
    static func slug(_ heading: String) -> String {
        let text = heading
            .replacing(#/\[([^\]]*)\]\([^)]*\)/#) { String($0.1) }
            .replacing(#/[`*]/#, with: "")
        return String(text.lowercased().unicodeScalars.compactMap { scalar -> Character? in
            if CharacterSet.whitespaces.contains(scalar) {
                return "-"
            }
            if CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_" {
                return Character(scalar)
            }
            return nil
        })
    }
}
