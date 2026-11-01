/// Derives the modules named by the mangled USR of a Swift declaration.
///
/// A Swift USR starts with the module that declares the entity (`s:10Foundation3URLV`), or with a standard library
/// substitution (`s:Si`, `s:SS`). Members declared in an extension carry the module of the extension after the
/// extended type (`s:SS10FoundationE4data...`). Clang USRs (`c:objc(cs)NSView`) and imported Objective-C types
/// (`s:So...`) do not name their module and yield no module here.
enum SystemModuleUsr {
    static func modules(in usr: String) -> Set<String> {
        guard usr.hasPrefix("s:") else { return [] }

        var chars = Substring(usr.dropFirst(2))
        var modules: Set<String> = []
        var isFirstToken = true

        while let first = chars.first {
            if first == "s", isFirstToken {
                modules.insert("Swift")
                chars = chars.dropFirst()
            } else if first == "S", let second = chars.dropFirst().first, second.isLetter {
                if isFirstToken {
                    if second == "o" || second == "C" {
                        // Imported Clang declaration, whose module is not part of the USR.
                        return modules
                    }

                    modules.insert(second == "c" ? "_Concurrency" : "Swift")
                }
                chars = chars.dropFirst(2)
            } else if first.isNumber, first != "0" {
                let digits = chars.prefix(while: \.isNumber)
                guard let length = Int(digits) else { return modules }

                let rest = chars.dropFirst(digits.count)
                guard rest.count >= length else { return modules }

                let identifier = String(rest.prefix(length))
                chars = rest.dropFirst(length)

                if isFirstToken {
                    modules.insert(identifier)
                } else if chars.first == "E" {
                    modules.insert(identifier)
                    return modules
                }
            } else {
                return modules
            }

            isFirstToken = false
        }

        return modules
    }
}
