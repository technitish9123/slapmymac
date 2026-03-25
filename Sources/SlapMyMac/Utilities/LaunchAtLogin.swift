import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        // SMAppService crashes if the app has no bundle identifier
        // (e.g., running as a bare SwiftPM executable).
        guard Bundle.main.bundleIdentifier != nil else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    static func toggle(_ enable: Bool) {
        guard Bundle.main.bundleIdentifier != nil else {
            print("LaunchAtLogin: not available without bundle identifier")
            return
        }
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("LaunchAtLogin error: \(error)")
        }
    }
}
