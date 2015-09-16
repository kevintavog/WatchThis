//
//  WatchThis
//

import Cocoa
import RangicCore

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{
    @IBOutlet weak var window: NSWindow!

    // MARK: Application hooks
    func applicationDidFinishLaunching(aNotification: NSNotification)
    {
        Preferences.setMissingDefaults()
    }

    func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication) -> Bool
    {
        return true
    }

    func applicationShouldTerminate(sender: NSApplication) -> NSApplicationTerminateReply
    {
        Logger.log("TODO: Close depending on state of the show list controller")
        return NSApplicationTerminateReply.TerminateNow
    }
}

