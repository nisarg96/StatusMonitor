import ServiceManagement
import StatusMonitorCore

/// Login item through SMAppService.mainApp (macOS 13+). This is the system's own login-item API, so it needs
/// no entitlement, no helper, and no password. The user can also remove it in System Settings → Login Items.
final class SMAppLoginItemService: LoginItemService {
    init() {}

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            // Already enabled means there is nothing to do.
            guard !isEnabled else { return }
            try SMAppService.mainApp.register()
        } else {
            guard isEnabled || SMAppService.mainApp.status == .requiresApproval else { return }
            try SMAppService.mainApp.unregister()
        }
    }
}
