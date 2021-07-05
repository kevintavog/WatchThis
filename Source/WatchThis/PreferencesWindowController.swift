//
//  WatchThis
//

import AppKit
import RangicCore
import Async

class PreferencesWindowController : NSWindowController
{
    @IBOutlet weak var locationLookup: NSTextField!
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

        locationLookup.stringValue = Preferences.baseLocationLookup
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
            ReverseNameLookupProvider.set(host: Preferences.baseLocationLookup)
            let response = ReverseNameLookupProvider().lookup(latitude: 51.484509, longitude: 0.002570)

            Async.main {
                self.testOsmWorkingIndicator.isHidden = true
                self.testOsmWorkingIndicator.stopAnimation(sender)

                let succeeded = response.description.count > 0
                let imageName = succeeded ? "SucceededCheck" : "FailedCheck"
                self.testOsmResultImage.image = NSImage(named: imageName)

                if !succeeded {
                    Logger.info("Response: \(response)")
                    let code = "You need to give back an error code..." // response["apiStatusCode"]
                    let message = "You gotta provide a message" // response["apiMessage"]
                    var error = ""
                    error = "code: \(code); "
                    error += "\(message)"
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

    @objc
    func windowWillClose(_ notification: Notification) {
        updateBaseLocationLookup()
        updateFindAPhotoHost()
        NSApplication.shared.stopModal()
    }

    func updateBaseLocationLookup() {
        Preferences.baseLocationLookup = locationLookup!.stringValue
        ReverseNameLookupProvider.set(host: Preferences.baseLocationLookup)
        Logger.info("Placename lookups are now via \(Preferences.baseLocationLookup)")

    }
    
    func updateFindAPhotoHost() {
        Preferences.findAPhotoHost = findAPhotoHost!.stringValue
        Logger.info("FindAPhoto host is now \(Preferences.findAPhotoHost)")
    }
}
