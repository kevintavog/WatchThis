//
//  WatchThis
//

import Cocoa
import RangicCore
import CocoaLumberjackSwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var listController: ShowListController!

    // MARK: Application hooks
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        #if DEBUG
            dynamicLogLevel = DDLogLevel.verbose
            #else
            dynamicLogLevel = DDLogLevel.info
        #endif

        Logger.configure()
        Preferences.setMissingDefaults()
        ReverseNameLookupProvider.set(host: Preferences.baseLocationLookup)
        Logger.info("Placename lookups via \(Preferences.baseLocationLookup)")

        listController.addKeyboardShorcutToMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
    {
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply
    {
        let close = listController != nil ? listController!.canClose() : true
        return close ? NSApplication.TerminateReply.terminateNow : NSApplication.TerminateReply.terminateCancel
    }
    
    @IBAction func preferences(_ sender: AnyObject)
    {
        let preferencesController = PreferencesWindowController(windowNibName: "Preferences")
        NSApplication.shared.runModal(for: preferencesController.window!)
    }

    func application(_ application: NSApplication, willPresentError error: Error) -> Error
    {
        Logger.error("willPresentError: \(error)")
        return error
    }

}
