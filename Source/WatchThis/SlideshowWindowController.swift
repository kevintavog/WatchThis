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
Logger.log("awakeFromNib: self - \(self.hashValue)")
    }

    func setDataModel(data: SlideshowData)
    {
        driver = SlideshowDriver(data: data, delegate: self)
        Logger.log("setDataModel: self - \(self.hashValue); driver - \(driver?.hashValue)")
    }

    // MARK: Actions
    @IBAction func pause(sender: AnyObject)
    {
Logger.log("clicked 'pause'")
Logger.log("pause: self - \(self.hashValue); driver - \(driver?.hashValue)")
        driver?.pauseOrResume()
    }

    @IBAction func play(sender: AnyObject)
    {
Logger.log("clicked 'play'")
        driver?.play()
    }

    @IBAction func nextImage(sender: AnyObject)
    {
Logger.log("clicked 'next'")
        driver?.next()
    }

    // MARK: SlideshowDriverDelegate
    func show(mediaData: MediaData)
    {
        Logger.log("Show \(mediaData.url.path!)")
    }

    func stateChanged(currentState: SlideshowDriver.DriverState)
    {
Logger.log("State changed to \(currentState)")
        updateUiState()
    }

    func updateUiState()
    {
        playButton?.hidden = true
    }
}