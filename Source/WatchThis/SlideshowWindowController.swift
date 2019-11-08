//
//

import AppKit
import AVFoundation
import AVKit
import RangicCore

import Async

class SlideshowWindowController : NSWindowController, NSWindowDelegate, SlideshowDriverDelegate
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

    var mediaList: MediaList?
    var driver: SlideshowDriver?

    var mediaContainer = MediaContainer(numPanels: 1)

    let secondsToHideControl = 2.0
    var lastMouseMovedTime = 0.0
    var hideControlsTimer:Timer? = nil


    // MARK: initialization
    override func awakeFromNib()
    {
        super.awakeFromNib()
        window?.backgroundColor = NSColor.black

        infoText?.isHidden = true

        mediaContainer.create(window: window, textField: infoText)

        updateUiState()

        lastMouseMovedTime = Date().timeIntervalSinceReferenceDate
        window?.acceptsMouseMovedEvents = true

        showControls()
    }

    var numberOfViews: UInt { get { return mediaContainer.numPanels } }

    func setDataModel(_ data: SlideshowData, mediaList: MediaList) {
        self.mediaList = mediaList
        driver = SlideshowDriver(list: mediaList, data: data, delegate: self)
        if let name = data.name {
            window?.title = "Slideshow - \(name)"
        }
    }

    // MARK: Actions
    @IBAction func pause(_ sender: AnyObject) {
        if driver?.driverState == SlideshowDriver.DriverState.paused {
            driver?.play()
        } else {
            driver?.pause()
        }
    }

    @IBAction func play(_ sender: AnyObject) {
        driver?.play()
    }

    @IBAction func nextImage(_ sender: AnyObject) {
        driver?.next()
    }

    @IBAction func previousImage(_ sender: AnyObject) {
        driver?.previous()
    }

    @IBAction func closeSlideshow(_ sender: AnyObject) {
        driver?.stop()
    }

    @IBAction func viewOne(_ sender: AnyObject) {
        if mediaContainer.numPanels != 1 {
            mediaContainer.close()
            
            mediaContainer = MediaContainer(numPanels: 1)
            mediaContainer.create(window: window, textField: infoText)
        }

        driver?.nextSlide()
    }

    @IBAction func viewFour(_ sender: AnyObject) {
        if mediaContainer.numPanels != 4 {
            mediaContainer.close()
            
            mediaContainer = MediaContainer(numPanels: 4)
            mediaContainer.create(window: window, textField: infoText)
            
            driver?.nextSlide()
            driver?.nextSlide()
            driver?.nextSlide()
            driver?.nextSlide()
        }
    }

    @IBAction func toggleFullScreen(_ sender: AnyObject) {
        window?.toggleFullScreen(sender);
    }


    // MARK: Control view management
    override func mouseMoved(with theEvent: NSEvent) {
        super.mouseMoved(with: theEvent)
        showControls()
    }

    override func keyDown(with theEvent: NSEvent) {
        showControls()
        super.keyDown(with: theEvent)
    }

    func showControls() {
        if hideControlsTimer != nil {
            hideControlsTimer?.invalidate()
        }

        hideControlsTimer = Timer.scheduledTimer(
            timeInterval: secondsToHideControl, target: self, selector: #selector(SlideshowWindowController.hideControlsTimerFired(_:)), userInfo: nil, repeats: true)
        controlsView.isHidden = false
    }

    func hideControls() {
        if hideControlsTimer != nil {
            hideControlsTimer?.invalidate()
            hideControlsTimer = nil
        }

        controlsView.isHidden = true
    }

    @objc func hideControlsTimerFired(_ someTimer: Timer) {
        hideControls()
    }

    func updateUiState() {
        if driver != nil {
            switch driver!.driverState {
            case .created:
                playButton?.isHidden = false
                pauseButton?.isHidden = true
            case .playing:
                playButton?.isHidden = true
                pauseButton?.isHidden = false
            case .paused:
                playButton?.isHidden = false
                pauseButton?.isHidden = true
            case .stopped:
                playButton?.isHidden = true
                pauseButton?.isHidden = true
            }
        } else {
            playButton?.isHidden = true
            pauseButton?.isHidden = true
        }

        let isFullScreen = window!.styleMask.contains(NSWindow.StyleMask.fullScreen)
        enterFullScreenButton?.isHidden = isFullScreen
        exitFullScreenButton?.isHidden = !isFullScreen
    }


    // MARK: SlideshowDriverDelegate
    func show(_ mediaData: MediaData) {
        NSCursor.setHiddenUntilMouseMoves(true)

        Logger.info("Show \(mediaData.url.path)")
        mediaContainer.show(mediaData: mediaData, driver: driver)
    }

    func stateChanged(_ currentState: SlideshowDriver.DriverState) {
        updateUiState()
    }

    func pauseVideo() {
        Logger.info("controller.pauseVideo")
        mediaContainer.pauseVideo()
    }

    func resumeVideo() {
        Logger.info("controller.resumeVideo")
        mediaContainer.resumeVideo()
    }
    
    func showAlert(_ message: String) {
        Logger.info("showAlert: \(message)")

        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "Close")
        alert.runModal()
    }


    // MARK: NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        mediaContainer.close()
        driver?.stop()
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        updateUiState()
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        updateUiState()
    }

    func windowDidResize(_ notification: Notification) {
        mediaContainer.resize(window)
    }
}
