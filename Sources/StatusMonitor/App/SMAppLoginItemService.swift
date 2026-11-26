import ServiceManagement
import StatusMonitorCore

/**
 The login item, registered through `SMAppService.mainApp` (macOS 13 and later).

 This is the system's own login item API, so it needs no entitlement, no helper and no password. The user can also
 remove the item in System Settings → Login Items.
 */
final class SMAppLoginItemService: LoginItemService {
    /// Creates the service. It holds no state, because the system keeps the login item status.
    init() {}

    /// Whether the app is registered as a login item and enabled.
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /**
     Registers or unregisters the app as a login item. Calls that would change nothing return without effect.

     - Parameter enabled: True to open the app at login, false to remove it.
     - Throws: The error the system reports when registering or unregistering fails.
     */
    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard !isEnabled else { return }
            try SMAppService.mainApp.register()
        } else {
            guard isEnabled || SMAppService.mainApp.status == .requiresApproval else { return }
            try SMAppService.mainApp.unregister()
        }
    }
}
