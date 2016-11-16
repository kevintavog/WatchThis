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

    
    @IBOutlet weak var findAPhotoHost: NSTextField!
    @IBOutlet weak var testFindAPhotoIndicator: NSProgressIndicator!
    @IBOutlet weak var testFindAPhotoResultImage: NSImageView!
    @IBOutlet weak var testFindAPhotoErrorMessage: NSTextField!


    override func awakeFromNib()
    {
        movieVolume!.floatValue = Preferences.videoPlayerVolume
        movieVolumeLabel!.floatValue = movieVolume!.floatValue

        openStreetMapHost.stringValue = Preferences.baseLocationLookup
        testOsmWorkingIndicator!.isHidden = true
        testOsmErrorMessage.stringValue = ""

        findAPhotoHost.stringValue = Preferences.findAPhotoHost
        testFindAPhotoIndicator!.isHidden = true
        testFindAPhotoErrorMessage.stringValue = ""
    }

    @IBAction func testOpenStreetMapHost(_ sender: AnyObject)
    {
        updateBaseLocationLookup()
        testOsmWorkingIndicator.startAnimation(sender)
        testOsmWorkingIndicator.isHidden = false
        testOsmResultImage.image = nil
        testOsmErrorMessage.stringValue = ""

        Logger.info("Test location lookup host: \(Preferences.baseLocationLookup)")

        Async.background {
            let response = OpenMapLookupProvider().lookup(51.484509, longitude: 0.002570)

            Async.main {
                self.testOsmWorkingIndicator.isHidden = true
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

    @IBAction func movieVolumeUpdated(_ sender: AnyObject)
    {
        movieVolumeLabel!.floatValue = movieVolume!.floatValue
        Preferences.videoPlayerVolume = movieVolume!.floatValue
    }

    @IBAction func testFindAPhotoHost(_ sender: AnyObject)
    {
        let host = findAPhotoHost!.stringValue

        testFindAPhotoIndicator.startAnimation(sender)
        testFindAPhotoIndicator.isHidden = false
        testFindAPhotoResultImage.image = nil
        testFindAPhotoErrorMessage.stringValue = ""

        Logger.info("Test FindAPhoto host: \(host)")

        Async.background {
            FindAPhotoResults.search(
                host,
                text: "",
                first: 1,
                count: 1,
                completion: { (result: FindAPhotoResults) -> () in
                    Async.main {
                        self.testFindAPhotoIndicator.isHidden = true
                        self.testFindAPhotoIndicator.stopAnimation(sender)
                        
                        let succeeded = !result.hasError
                        self.testFindAPhotoResultImage.image = NSImage(named: succeeded ? "SucceededCheck" : "FailedCheck")
                        if !succeeded {
                            self.testFindAPhotoErrorMessage.stringValue = result.errorMessage!
                        } else {
                            self.testFindAPhotoErrorMessage.stringValue = "Succeeded with a total of \(result.totalMatches!) matches"
                        }
                    }
            })            
        }
    }

    func windowWillClose(_ notification: Notification)
    {
        updateBaseLocationLookup()
        updateFindAPhotoHost()
        NSApplication.shared().stopModal()
    }

    func updateBaseLocationLookup()
    {
        Preferences.baseLocationLookup = openStreetMapHost!.stringValue
        OpenMapLookupProvider.BaseLocationLookup = Preferences.baseLocationLookup
        Logger.info("Placename lookups are now via \(OpenMapLookupProvider.BaseLocationLookup)")
    }
    
    func updateFindAPhotoHost()
    {
        Preferences.findAPhotoHost = findAPhotoHost!.stringValue
        Logger.info("FindAPhoto host is now \(Preferences.findAPhotoHost)")
    }
}
