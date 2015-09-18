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
    @IBOutlet weak var indexText: NSTextField!
    @IBOutlet weak var controlsView: NSView!
    @IBOutlet weak var closeButton: NSButton!
    @IBOutlet weak var exitFullScreenButton: NSButton!
    @IBOutlet weak var enterFullScreenButton: NSButton!
    @IBOutlet weak var nextButton: NSButton!
    @IBOutlet weak var playButton: NSButton!

    var driver: SlideshowDriver?
    var imageView: NSImageView?
    var videoView: AVPlayerView!

    let secondsToHideControl = 2.0
    var lastMouseMovedTime = 0.0
    var hideControlsTimer:NSTimer? = nil


    // MARK: initialization
    override func awakeFromNib()
    {
        super.awakeFromNib()
        window?.backgroundColor = NSColor.blackColor()

        imageView = createImageView()
        window?.contentView?.addSubview(imageView!, positioned: NSWindowOrderingMode.Below, relativeTo: window?.contentView?.subviews[0])
        videoView = createVideoView()
        window?.contentView?.addSubview(videoView!, positioned: NSWindowOrderingMode.Below, relativeTo: window?.contentView?.subviews[0])

        imageView?.hidden = true
        videoView?.hidden = true

        infoText.stringValue = ""
        indexText.stringValue = ""
        updateUiState()

        lastMouseMovedTime = NSDate().timeIntervalSinceReferenceDate
        window?.acceptsMouseMovedEvents = true

        showControls()
    }

    func setDataModel(data: SlideshowData)
    {
        driver = SlideshowDriver(data: data, delegate: self)
        window?.title = "Slideshow - \(data.name!)"
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

    @IBAction func previousImage(sender: AnyObject)
    {
        driver?.previous()
    }

    @IBAction func closeSlideshow(sender: AnyObject)
    {
        driver?.stop()
    }

    @IBAction func toggleFullScreen(sender: AnyObject)
    {
        window?.toggleFullScreen(sender);
    }


    // MARK: Control view management
    override func mouseMoved(theEvent: NSEvent)
    {
        super.mouseMoved(theEvent)
        showControls()
    }

    override func keyDown(theEvent: NSEvent)
    {
        showControls()
        super.keyDown(theEvent)
    }

    func showControls()
    {
        if hideControlsTimer != nil {
            hideControlsTimer?.invalidate()
        }

        hideControlsTimer = NSTimer.scheduledTimerWithTimeInterval(
            secondsToHideControl, target: self, selector: "hideControlsTimerFired:", userInfo: nil, repeats: true)
        controlsView.hidden = false
    }

    func hideControls()
    {
        if hideControlsTimer != nil {
            hideControlsTimer?.invalidate()
            hideControlsTimer = nil
        }

        controlsView.hidden = true
    }

    func hideControlsTimerFired(someTimer: NSTimer)
    {
        hideControls()
    }

    func updateUiState()
    {
        playButton?.hidden = driver?.driverState == .Playing
        pauseButton?.hidden = driver?.driverState == .Paused

        let isFullScreen = ((window?.styleMask)! & NSFullScreenWindowMask) == NSFullScreenWindowMask
        enterFullScreenButton?.hidden = isFullScreen
        exitFullScreenButton?.hidden = !isFullScreen
    }


    // MARK: SlideshowDriverDelegate
    func show(mediaData: MediaData) -> Double?
    {
        Logger.log("Show \(mediaData.url.path!)")
        switch mediaData.type! {
        case .Image:
            displayInfo(mediaData)
            return showImage(mediaData)
        case .Video:
            displayInfo(mediaData)
            return showVideo(mediaData)
        default:
            Logger.log("Unhandled media type: \(mediaData.type)")
            return nil
        }
    }

    func stateChanged(currentState: SlideshowDriver.DriverState)
    {
        updateUiState()
    }


    //  MARK: show image/video
    func displayInfo(mediaData: MediaData)
    {
        let parentPath = ((mediaData.url!.path as NSString!).stringByDeletingLastPathComponent as NSString).lastPathComponent
        let displayInfo = "\(parentPath)"
        displayInfoString(displayInfo)

        displayIndexString("\(driver!.currentIndex) of \(driver!.totalCount)")

        if let location = mediaData.location {
            Async.background {
                var placename = location.placenameAsString()
                if placename.characters.count == 0 {
                    placename = location.toDms()
                }

                Async.main {
                    self.displayInfoString("\(parentPath)      \(placename)")
                }
            }
        }
    }

    func displayInfoString(displayInfo: String)
    {
        let fullRange = NSRange(location: 0, length: displayInfo.characters.count)
        let attributeString = NSMutableAttributedString(string: displayInfo)
        attributeString.addAttribute(NSBackgroundColorAttributeName, value: NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0.75), range: fullRange)
        infoText.attributedStringValue = attributeString
    }

    func displayIndexString(index: String)
    {
        let fullRange = NSRange(location: 0, length: index.characters.count)
        let attributeString = NSMutableAttributedString(string: index)
        attributeString.addAttribute(NSBackgroundColorAttributeName, value: NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0.75), range: fullRange)
        indexText.attributedStringValue = attributeString
    }

    func showImage(mediaData: MediaData) -> Double?
    {
        stopVideoPlayer()
        imageView?.image = nil
        imageView?.hidden = false
        videoView?.hidden = true

        Async.background {
            let imageSource = CGImageSourceCreateWithURL(mediaData.url, nil)
            let image = CGImageSourceCreateImageAtIndex(imageSource!, 0, nil)
            let nsImage = NSImage(CGImage: image!, size: NSSize(width: CGImageGetWidth(image), height: CGImageGetHeight(image)))

            Async.main {
                self.imageView?.image = nsImage;
            }
        }
        return 0
    }

    func showVideo(mediaData: MediaData) -> Double?
    {
        stopVideoPlayer()
        imageView?.hidden = true
        imageView?.image = nil
        videoView?.hidden = false

        videoView.player = AVPlayer(URL: mediaData.url)
videoView.player?.volume = 0.1

        videoView.player?.play()
        return Double(CMTimeGetSeconds((videoView.player?.currentItem?.asset.duration)!))
    }

    func stopVideoPlayer()
    {
        if let player = videoView?.player {
//            player.removeObserver(self, forKeyPath: "volume", context: nil)
            player.pause()
            videoView?.player = nil
        }
    }


    // MARK: NSWindowDelegate
    func windowWillClose(notification: NSNotification)
    {
        driver?.stop()
    }

    func windowDidEnterFullScreen(notification: NSNotification)
    {
        updateUiState()
    }

    func windowDidExitFullScreen(notification: NSNotification)
    {
        updateUiState()
    }


    // MARK: view creation
    func createImageView() -> NSImageView
    {
        let imageView = NSImageView(frame: (window?.contentView?.frame)!)
        imageView.imageScaling = NSImageScaling.ScaleProportionallyDown
        imageView.autoresizingMask = NSAutoresizingMaskOptions(rawValue: NSAutoresizingMaskOptions.ViewHeightSizable.rawValue
            | NSAutoresizingMaskOptions.ViewWidthSizable.rawValue)
        return imageView
    }

    func createVideoView() -> AVPlayerView
    {
        let videoView = AVPlayerView(frame: (window?.contentView?.frame)!)
        videoView.autoresizingMask = NSAutoresizingMaskOptions(rawValue: NSAutoresizingMaskOptions.ViewHeightSizable.rawValue
            | NSAutoresizingMaskOptions.ViewWidthSizable.rawValue)
        return videoView
    }
}