//
//  WatchThis
//

import Cocoa
import RangicCore

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var listController: ShowListController!

    // MARK: Application hooks
    func applicationDidFinishLaunching(aNotification: NSNotification)
    {
        Logger.configure()
        Preferences.setMissingDefaults()
        OpenMapLookupProvider.BaseLocationLookup = Preferences.baseLocationLookup
        Logger.info("Placename lookups via \(OpenMapLookupProvider.BaseLocationLookup)")

        listController.addKeyboardShorcutToMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool
    {
        return true
    }

    func applicationShouldTerminate(sender: NSApplication) -> NSApplicationTerminateReply
    {
        let close = listController != nil ? listController!.windowShouldClose(sender) : true
        return close ? NSApplicationTerminateReply.TerminateNow : NSApplicationTerminateReply.TerminateCancel
    }
    
    @IBAction func preferences(sender: AnyObject)
    {
        let preferencesController = PreferencesWindowController(windowNibName: "Preferences")
        NSApplication.sharedApplication().runModalForWindow(preferencesController.window!)
    }
}
