import Foundation
import SPMProjectKit

func main() {
    print(SPMProject().text)
    print(PublicCrossModuleReferenced.self)
    print(LocalizationUsage.message)
    print(LocalizationUsage.ternaryMessage(first: true, second: false))
}

main()
