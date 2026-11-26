import Foundation

/**
 Launch-at-login for the app.

 The system holds the real state, so `isEnabled` is always read from it.
 */
public protocol LoginItemService: AnyObject {
    /// True only when the system reports the app as an enabled login item.
    var isEnabled: Bool { get }

    /**
     Registers or unregisters the app as a login item.

     - Parameter enabled: True to open the app at login, false to remove it.
     - Throws: The error the system reports when registering or unregistering fails.
     */
    func setEnabled(_ enabled: Bool) throws
}
