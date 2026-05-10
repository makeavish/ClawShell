import AppKit
import ClawShellCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarApp: MenuBarApp?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let app = MenuBarApp(services: ClawShellServices())
        menuBarApp = app
        app.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarApp?.stop()
    }
}
