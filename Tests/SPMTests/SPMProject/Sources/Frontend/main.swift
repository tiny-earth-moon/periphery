import Foundation
import SPMDynamicKeysKit
import SPMProjectKit

func main() {
    print(SPMProject().text)
    print(PublicCrossModuleReferenced.self)
    print(LocalizationUsage.message)
    print(LocalizationUsage.ternaryMessage(first: true, second: false))
    print(LocalizationUsage.runtimeMessages(suffix: "alpha"))
    print(DynamicKeys.title(keyName: "dyn_runtime_key"))
    print(DynamicKeys.mixedTitle(flag: false, keyName: "dyn_runtime_key"))
}

main()
