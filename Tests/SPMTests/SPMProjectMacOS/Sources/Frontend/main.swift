import Foundation
import SPMProjectMacOSKit
import SwiftUI

_ = StateMacroView().$rootRead

@MainActor
func main() {
    // Reference the view controller class (it's also referenced from the xib)
    _ = SPMXibViewController.self
    _ = SPMImplicitXibViewController.self
    _ = StateMacroView().body
    if #available(macOS 14, *) {
        retainObservationModels()
    }
}

main()

extension StateMacroView {
    func bindingFromOtherFile() -> Binding<Bool> {
        $crossFile
    }
}
