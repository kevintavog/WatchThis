//
//

import AppKit
import RangicCore

class SlideshowWindowController : NSWindowController, SlideshowDriverDelegate
{
    @IBOutlet weak var previousButton: NSButton!
    @IBOutlet weak var pauseButton: NSButton!
    @IBOutlet weak var infoText: NSTextField!
    @IBOutlet weak var controlsView: NSView!
    @IBOutlet weak var closeButton: NSButton!
    @IBOutlet weak var exitFullScreenButton: NSButton!
    @IBOutlet weak var enterFullScreenButton: NSButton!
    @IBOutlet weak var nextButton: NSButton!
    @IBOutlet weak var playButton: NSButton!

    var driver: SlideshowDriver?


    // MARK: initialization
    override func awakeFromNib()
    {
        super.awakeFromNib()
        window!.backgroundColor = NSColor.blackColor()

        infoText.stringValue = ""
        updateUiState()
    }

    func setDataModel(data: SlideshowData)
    {
        driver = SlideshowDriver(data: data, delegate: self)
    }

    // MARK: Actions
    @IBAction func pause(sender: AnyObject)
    {
        driver?.pauseOrResume()
    }

    @IBAction func play(sender: AnyObject)
    {
        driver?.play()
    }

    @IBAction func nextImage(sender: AnyObject)
    {
        driver?.next()
    }

    // MARK: SlideshowDriverDelegate
    func show(mediaData: MediaData)
    {
        Logger.log("Show \(mediaData.url.path!)")
    }

    func stateChanged(currentState: SlideshowDriver.DriverState)
    {
        updateUiState()
    }

    func updateUiState()
    {
        playButton?.hidden = driver?.driverState == .Playing
        pauseButton?.hidden = driver?.driverState == .Paused
        enterFullScreenButton?.hidden = true
    }
}