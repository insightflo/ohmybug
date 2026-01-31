import SwiftUI

@Observable
final class AppSettings {
    var autoApplyFixes: Bool {
        didSet { UserDefaults.standard.set(autoApplyFixes, forKey: "autoApplyFixes") }
    }
    var runBuildCheck: Bool {
        didSet { UserDefaults.standard.set(runBuildCheck, forKey: "runBuildCheck") }
    }
    var glmAPIKey: String {
        didSet { UserDefaults.standard.set(glmAPIKey, forKey: "glmAPIKey") }
    }

    init() {
        let defaults = UserDefaults.standard
        self.autoApplyFixes = defaults.object(forKey: "autoApplyFixes") as? Bool ?? true
        self.runBuildCheck = defaults.object(forKey: "runBuildCheck") as? Bool ?? true
        self.glmAPIKey = defaults.string(forKey: "glmAPIKey") ?? ""
    }
}
