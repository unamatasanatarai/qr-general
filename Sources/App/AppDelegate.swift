import Cocoa

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: QRWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = MainMenu.build()

        let controller = QRWindowController()
        controller.showWindow(nil)
        windowController = controller
        NSApp.activate(ignoringOtherApps: true)
        NSLog("%@ started successfully.", AppConfig.appName)
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
