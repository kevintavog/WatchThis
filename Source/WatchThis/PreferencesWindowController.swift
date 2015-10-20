//
//  WatchThis
//

import AppKit
import RangicCore
import Async

class PreferencesWindowController : NSWindowController
{
    @IBOutlet weak var openStreetMapHost: NSTextField!
    @IBOutlet weak var movieVolume: NSSlider!
    @IBOutlet weak var movieVolumeLabel: NSTextField!

    @IBOutlet weak var testOsmWorkingIndicator: NSProgressIndicator!
    @IBOutlet weak var testOsmResultImage: NSImageView!
    @IBOutlet weak var testOsmErrorMessage: NSTextField!


    override func awakeFromNib()
    {
        movieVolume!.floatValue = Preferences.videoPlayerVolume
        movieVolumeLabel!.floatValue = movieVolume!.floatValue

        openStreetMapHost.stringValue = Preferences.baseLocationLookup

        testOsmWorkingIndicator!.hidden = true
        testOsmErrorMessage.stringValue = ""
    }

    @IBAction func testOpenStreetMapHost(sender: AnyObject)
    {
        updateBaseLocationLookup()
        testOsmWorkingIndicator.startAnimation(sender)
        testOsmWorkingIndicator.hidden = false
        testOsmResultImage.image = nil
        testOsmErrorMessage.stringValue = ""

        Logger.info("Test host: \(Preferences.baseLocationLookup)")

        Async.background {
            let response = OpenMapLookupProvider().lookup(51.484509, longitude: 0.002570)

            Async.main {
                self.testOsmWorkingIndicator.hidden = true
                self.testOsmWorkingIndicator.stopAnimation(sender)

                let succeeded = response.keys.contains("DisplayName")
                let imageName = succeeded ? "SucceededCheck" : "FailedCheck"
                self.testOsmResultImage.image = NSImage(named: imageName)

                if !succeeded {
                    Logger.info("Response: \(response)")
                    let code = response["apiStatusCode"]
                    let message = response["apiMessage"]
                    var error = ""
                    if code != nil {
                        error = "code: \(code!); "
                    }
                    if message != nil {
                        error += "\(message!)"
                    } else {
                        error += "unknown error"
                    }
                    self.testOsmErrorMessage.stringValue = error
                }
            }
        }
    }

    @IBAction func movieVolumeUpdated(sender: AnyObject)
    {
        movieVolumeLabel!.floatValue = movieVolume!.floatValue
        Preferences.videoPlayerVolume = movieVolume!.floatValue
    }

    func windowWillClose(notification: NSNotification)
    {
        updateBaseLocationLookup()
        NSApplication.sharedApplication().stopModal()
    }

    func updateBaseLocationLookup()
    {
        Preferences.baseLocationLookup = openStreetMapHost!.stringValue
        OpenMapLookupProvider.BaseLocationLookup = Preferences.baseLocationLookup
        Logger.info("Placename lookups are now via \(OpenMapLookupProvider.BaseLocationLookup)")
    }
}