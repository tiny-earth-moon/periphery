import Foundation
import SystemPackage
@testable import TestShared

var SPMProjectPath: FilePath {
    ProjectRootPath.appending("Tests/SPMTests/SPMProject")
}

#if os(macOS)
    var SPMProjectMacOSPath: FilePath {
        ProjectRootPath.appending("Tests/SPMTests/SPMProjectMacOS")
    }

    var SPMProjectMultiVariantPath: FilePath {
        ProjectRootPath.appending("Tests/SPMTests/SPMProjectMultiVariant")
    }
#endif
