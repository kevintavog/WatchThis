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

    var mediaList: MediaList?
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

    func setDataModel(data: SlideshowData, mediaList: MediaList)
    {
        self.mediaList = mediaList
        driver = SlideshowDriver(list: mediaList, data: data, delegate: self)
        if let name = data.name {
            window?.title = "Slideshow - \(name)"
        }
    }

    // MARK: Actions
    @IBAction func pause(sender: AnyObject)
    {
        driver?.pause()
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
        if driver != nil {
            switch driver!.driverState {
            case .Created:
                playButton?.hidden = false
                pauseButton?.hidden = true
            case .Playing:
                playButton?.hidden = true
                pauseButton?.hidden = false
            case .Paused:
                playButton?.hidden = false
                pauseButton?.hidden = true
            case .Stopped:
                playButton?.hidden = true
                pauseButton?.hidden = true
            }
        } else {
            playButton?.hidden = true
            pauseButton?.hidden = true
        }

        let isFullScreen = ((window?.styleMask)! & NSFullScreenWindowMask) == NSFullScreenWindowMask
        enterFullScreenButton?.hidden = isFullScreen
        exitFullScreenButton?.hidden = !isFullScreen
    }


    // MARK: SlideshowDriverDelegate
    func show(mediaData: MediaData)
    {
        NSCursor.setHiddenUntilMouseMoves(true)

        Logger.info("Show \(mediaData.url.path!)")
        switch mediaData.type! {
        case .Image:
            displayInfo(mediaData)
            showImage(mediaData)
        case .Video:
            displayInfo(mediaData)
            showVideo(mediaData)
        default:
            Logger.error("Unhandled media type: \(mediaData.type)")
        }
    }

    func stateChanged(currentState: SlideshowDriver.DriverState)
    {
        updateUiState()
    }

    func pauseVideo()
    {
        Logger.info("controller.pauseVideo")
        if let player = videoView!.player {
            player.pause()
        }
    }

    func resumeVideo()
    {
        Logger.info("controller.resumeVideo")
        if let player = videoView!.player {
            player.play()
        }
    }
    
    //  MARK: show image/video
    func displayInfo(mediaData: MediaData)
    {
        let parentPath = ((mediaData.url!.path as NSString!).stringByDeletingLastPathComponent as NSString).lastPathComponent
        let displayInfo = "\(parentPath)"
        displayInfoString(displayInfo)

        displayIndexString("\((mediaList?.currentIndex(driver!))!) of \((mediaList?.totalCount)!)")

        if let location = mediaData.location {
            Async.background {
                var placename = location.placenameAsString(PlaceNameFilter.Standard)
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

    func showVideo(mediaData: MediaData)
    {
        stopVideoPlayer()

        imageView?.hidden = true
        imageView?.image = nil
        videoView?.hidden = false

        videoView.player = AVPlayer(URL: mediaData.url)
        let player = videoView.player!
        player.volume = Preferences.videoPlayerVolume
        player.actionAtItemEnd = .None

        player.addObserver(self, forKeyPath: "volume", options: .New, context: nil)
//        player.addObserver(self, forKeyPath: "rate", options: .New, context: nil)
        Notifications.addObserver(self, selector: "videoDidEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: player.currentItem)

        videoView.player?.play()
    }

    func stopVideoPlayer()
    {
        if let player = videoView?.player {
            Notifications.removeObserver(self, object: player.currentItem)
//            player.removeObserver(self, forKeyPath: "rate")
            player.removeObserver(self, forKeyPath: "volume")
            player.pause()
            videoView?.player = nil
        }
    }

    func videoDidEnd(notification: NSNotification)
    {
        Async.main(after: 2.0) {
            self.driver?.videoDidEnd()
        }
    }

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String:AnyObject]?, context: UnsafeMutablePointer<Void>)
    {
        switch keyPath! {
        case "volume":
            if let volume = change![NSKeyValueChangeNewKey] as? Float {
                Preferences.videoPlayerVolume = volume
            }

        case "rate":
            if let rate = change![NSKeyValueChangeNewKey] as? Float {
                if rate == 0 {
                    driver!.pause()
                } else {
                    driver!.resume()
                }
            }

        default:
            Logger.error("Unhandled kv change: \(keyPath)")
        }
    }
    

    // MARK: NSWindowDelegate
    func windowWillClose(notification: NSNotification)
    {
        stopVideoPlayer()
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
        videoView.controlsStyle = .Floating
        videoView.showsFrameSteppingButtons = true
        return videoView
    }
}