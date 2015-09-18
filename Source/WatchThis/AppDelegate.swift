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
        Preferences.setMissingDefaults()
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
}

