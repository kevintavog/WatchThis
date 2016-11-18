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
            defaultDebugLevel = DDLogLevel.verbose
            #else
            defaultDebugLevel = DDLogLevel.info
        #endif
        Logger.configure()
        Preferences.setMissingDefaults()
        OpenMapLookupProvider.BaseLocationLookup = Preferences.baseLocationLookup
        Logger.info("Placename lookups via \(OpenMapLookupProvider.BaseLocationLookup)")

        listController.addKeyboardShorcutToMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
    {
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplicationTerminateReply
    {
        let close = listController != nil ? listController!.windowShouldClose(sender) : true
        return close ? NSApplicationTerminateReply.terminateNow : NSApplicationTerminateReply.terminateCancel
    }
    
    @IBAction func preferences(_ sender: AnyObject)
    {
        let preferencesController = PreferencesWindowController(windowNibName: "Preferences")
        NSApplication.shared().runModal(for: preferencesController.window!)
    }

    func application(_ application: NSApplication, willPresentError error: Error) -> Error
    {
        Logger.error("willPresentError: \(error)")
        return error
    }

}
