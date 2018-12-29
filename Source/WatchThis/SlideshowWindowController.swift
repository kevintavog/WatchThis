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
    var slideshowImageView: SlideshowImageView?
    var videoView: AVPlayerView!

    let secondsToHideControl = 2.0
    var lastMouseMovedTime = 0.0
    var hideControlsTimer:Timer? = nil


    // MARK: initialization
    override func awakeFromNib()
    {
        super.awakeFromNib()
        window?.backgroundColor = NSColor.black

        slideshowImageView = SingleSlideshowImageView()
        slideshowImageView?.create(window: window, textField: infoText)

        videoView = createVideoView()
        window?.contentView?.addSubview(videoView!, positioned: NSWindow.OrderingMode.below, relativeTo: window?.contentView?.subviews[0])

        videoView?.isHidden = true
        infoText?.isHidden = true

        updateUiState()

        lastMouseMovedTime = Date().timeIntervalSinceReferenceDate
        window?.acceptsMouseMovedEvents = true

        showControls()
    }

    var numberOfViews: UInt { get { return slideshowImageView!.numberOfViews } }

    func setDataModel(_ data: SlideshowData, mediaList: MediaList)
    {
        self.mediaList = mediaList
        driver = SlideshowDriver(list: mediaList, data: data, delegate: self)
        if let name = data.name {
            window?.title = "Slideshow - \(name)"
        }
    }

    // MARK: Actions
    @IBAction func pause(_ sender: AnyObject)
    {
        if driver?.driverState == SlideshowDriver.DriverState.paused {
            driver?.play()
        } else {
            driver?.pause()
        }
    }

    @IBAction func play(_ sender: AnyObject)
    {
        driver?.play()
    }

    @IBAction func nextImage(_ sender: AnyObject)
    {
        driver?.next()
    }

    @IBAction func previousImage(_ sender: AnyObject)
    {
        driver?.previous()
    }

    @IBAction func closeSlideshow(_ sender: AnyObject)
    {
        driver?.stop()
    }

    @IBAction func viewOne(_ sender: AnyObject) {
        slideshowImageView?.close()
        slideshowImageView = SingleSlideshowImageView()
        slideshowImageView?.create(window: window, textField: infoText)
        driver?.nextSlide()
    }

    @IBAction func viewFour(_ sender: AnyObject) {
        slideshowImageView?.close()
        slideshowImageView = MultiSlideshowImageView()
        slideshowImageView?.create(window: window, textField: infoText)

        for _ in 1...Int(slideshowImageView!.numberOfViews) {
            driver?.nextSlide()
        }
    }

    @IBAction func toggleFullScreen(_ sender: AnyObject)
    {
        window?.toggleFullScreen(sender);
    }


    // MARK: Control view management
    override func mouseMoved(with theEvent: NSEvent)
    {
        super.mouseMoved(with: theEvent)
        showControls()
    }

    override func keyDown(with theEvent: NSEvent)
    {
        showControls()
        super.keyDown(with: theEvent)
    }

    func showControls()
    {
        if hideControlsTimer != nil {
            hideControlsTimer?.invalidate()
        }

        hideControlsTimer = Timer.scheduledTimer(
            timeInterval: secondsToHideControl, target: self, selector: #selector(SlideshowWindowController.hideControlsTimerFired(_:)), userInfo: nil, repeats: true)
        controlsView.isHidden = false
    }

    func hideControls()
    {
        if hideControlsTimer != nil {
            hideControlsTimer?.invalidate()
            hideControlsTimer = nil
        }

        controlsView.isHidden = true
    }

    @objc func hideControlsTimerFired(_ someTimer: Timer)
    {
        hideControls()
    }

    func updateUiState()
    {
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
    func show(_ mediaData: MediaData)
    {
        NSCursor.setHiddenUntilMouseMoves(true)

        Logger.info("Show \(mediaData.url.path)")
        switch mediaData.type! {
        case .image:
            displayInfo(mediaData)
            let _ = showImage(mediaData)
        case .video:
            displayInfo(mediaData)
            showVideo(mediaData)
        default:
            Logger.error("Unhandled media type: \(mediaData.type)")
        }
    }

    func stateChanged(_ currentState: SlideshowDriver.DriverState)
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
    
    func showAlert(_ message: String)
    {
        Logger.info("showAlert: \(message)")

        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "Close")
        alert.runModal()
    }

    //  MARK: show image/video
    func displayInfo(_ mediaData: MediaData)
    {
        displayInfoString(mediaData, "")

        if let location = mediaData.location {
            Async.background {
                let placename = location.placenameAsString(PlaceNameFilter.standard)
                var missingLocation = ""
                if placename.count == 0 {
                    missingLocation = mediaData.parentPath
                }

                Async.main {
                    self.displayInfoString(mediaData, missingLocation)
                }
            }
        } else {
            self.displayInfoString(mediaData, mediaData.parentPath)
        }
    }

    func displayInfoString(_ mediaData: MediaData, _ missingLocation: String) {
        // Try to get text that will fit - but only try so hard
        let viewId = mediaData.url!.path
        var level = 1
        var info = displayInfoAttempt(mediaData, missingLocation, level)
        while level < 4 {
            if !slideshowImageView!.isTextTruncated(text: info, viewId: viewId) {
                break
            }
            level += 1
            info = displayInfoAttempt(mediaData, missingLocation, level)
        }

        slideshowImageView?.setText(text: info, viewId: viewId)
    }

    func displayInfoAttempt(_ mediaData: MediaData, _ missingLocation: String, _ level: Int) -> String {
        switch level {
        case 1:
            if let location = mediaData.location, location.hasPlacename() {
                let placename = location.placenameAsString(PlaceNameFilter.standard)
                return "\(mediaData.formattedDate())   \(placename)"
            } else {
                return "\(mediaData.formattedDate())   \(missingLocation)"
            }

        case 2:
            if let location = mediaData.location, location.hasPlacename() {
                let placename = location.placenameAsString(PlaceNameFilter.city)
                return "\(mediaData.formattedDate())   \(placename)"
            } else {
                return "\(mediaData.formattedDate())"
            }

        case 3:
            if let location = mediaData.location, location.hasPlacename() {
                let placename = location.placenameAsString(PlaceNameFilter.cityNoCountry)
                return "\(mediaData.formattedDate())   \(placename)"
            } else {
                return "\(mediaData.formattedDate())"
            }
            
        case 4:
            if let location = mediaData.location, location.hasPlacename() {
                return location.placenameAsString(PlaceNameFilter.city)
            } else {
                return "\(mediaData.formattedDate())"
            }
            
        default:
            if let location = mediaData.location, location.hasPlacename() {
                let placename = location.placenameAsString(PlaceNameFilter.standard)
                return "\(mediaData.formattedDate())   \(placename)"
            } else {
                if missingLocation.count > 0 {
                    return missingLocation
                }
                return mediaData.formattedDate()
            }
        }
    }

    func showImage(_ mediaData: MediaData) -> Double? {
        let viewId = mediaData.url!.path
        stopVideoPlayer()
//        slideshowImageView?.clearImage(viewId: viewId)
        slideshowImageView?.showImage(show: true, viewId: viewId)
        videoView?.isHidden = true

        Async.background {
            var nsImage: NSImage
            if let rotation = mediaData.rotation, rotation == ImageOrientation.topLeft.rawValue {
                nsImage = NSImage(byReferencing: mediaData.url)
                if nsImage.representations.count > 0 {
                    let imageRep = nsImage.representations[0]
                    nsImage.size = NSSize(width: imageRep.pixelsWide, height: imageRep.pixelsHigh)
                } else {
                    Logger.error("Failed loading '\(mediaData.url!.absoluteString)'")
                    self.nextImage(self)
                }
            } else {
                let imageSource = CGImageSourceCreateWithURL(mediaData.url! as CFURL, nil)
                if imageSource == nil {
                    nsImage = NSImage(byReferencing: mediaData.url!)
                } else {
                    let image = CGImageSourceCreateImageAtIndex(imageSource!, 0, nil)
                    nsImage = NSImage(cgImage: image!, size: NSSize(width: (image?.width)!, height: (image?.height)!))
                }
            }

            Async.main {
                self.slideshowImageView?.setImage(image: nsImage, viewId: viewId)
            }
        }
        return 0
    }

    func showVideo(_ mediaData: MediaData)
    {
        stopVideoPlayer()

//        slideshowImageView?.showImage(show: false, viewIndex: viewIndex)
//        slideshowImageView?.clearImage(viewIndex: viewIndex)
        videoView?.isHidden = false

        videoView.player = AVPlayer(url: mediaData.url)
        let player = videoView.player!
        player.volume = Preferences.videoPlayerVolume
        player.actionAtItemEnd = .none

        player.addObserver(self, forKeyPath: "volume", options: .new, context: nil)
        Notifications.addObserver(self, selector: #selector(SlideshowWindowController.videoDidEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime.rawValue, object: player.currentItem)

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

    @objc func videoDidEnd(_ notification: Notification)
    {
        Async.main(after: 2.0) {
            self.driver?.videoDidEnd()
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey:Any]?, context: UnsafeMutableRawPointer?)
    {
        switch keyPath! {
        case "volume":
            if let volume = change![NSKeyValueChangeKey.newKey] as? Float {
                Preferences.videoPlayerVolume = volume
            }

        case "rate":
            if let rate = change![NSKeyValueChangeKey.newKey] as? Float {
                if rate == 0 {
                    driver!.pause()
                } else {
                    driver!.resume()
                }
            }

        default:
            Logger.error("Unhandled kv change: \(String(describing: keyPath))")
        }
    }
    

    // MARK: NSWindowDelegate
    func windowWillClose(_ notification: Notification)
    {
        stopVideoPlayer()
        driver?.stop()
    }

    func windowDidEnterFullScreen(_ notification: Notification)
    {
        updateUiState()
    }

    func windowDidExitFullScreen(_ notification: Notification)
    {
        updateUiState()
    }

    func windowDidResize(_ notification: Notification) {
        slideshowImageView?.windowResized(window: window)
    }


    // MARK: view creation
    func createVideoView() -> AVPlayerView
    {
        let textheight = infoText.frame.height
        let videoView = AVPlayerView(frame: (window?.contentView?.frame.offsetBy(dx: 0, dy: textheight).insetBy(dx: 0, dy: textheight))!)
        videoView.autoresizingMask = NSView.AutoresizingMask(rawValue: NSView.AutoresizingMask.height.rawValue
            | NSView.AutoresizingMask.width.rawValue)
        videoView.controlsStyle = .floating
        videoView.showsFrameSteppingButtons = true
        return videoView
    }
}
