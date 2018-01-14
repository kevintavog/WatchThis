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
    var imageView: NSImageView?
    var videoView: AVPlayerView!

    let secondsToHideControl = 2.0
    var lastMouseMovedTime = 0.0
    var hideControlsTimer:Timer? = nil


    // MARK: initialization
    override func awakeFromNib()
    {
        super.awakeFromNib()
        window?.backgroundColor = NSColor.black

        imageView = createImageView()
        window?.contentView?.addSubview(imageView!, positioned: NSWindow.OrderingMode.below, relativeTo: window?.contentView?.subviews[0])
        videoView = createVideoView()
        window?.contentView?.addSubview(videoView!, positioned: NSWindow.OrderingMode.below, relativeTo: window?.contentView?.subviews[0])

        imageView?.isHidden = true
        videoView?.isHidden = true

        infoText.stringValue = ""
        updateUiState()

        lastMouseMovedTime = Date().timeIntervalSinceReferenceDate
        window?.acceptsMouseMovedEvents = true

        showControls()
    }

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
        let dateString = mediaData.formattedDate()
        let displayInfo = "\(dateString)"
        let parentPath = mediaData.parentPath
        displayInfoString(displayInfo)

        if let location = mediaData.location {
            Async.background {
                var placename = location.placenameAsString(PlaceNameFilter.standard)
                if placename.count == 0 {
                    placename = parentPath
                }

                Async.main {
                    self.displayInfoString("\(dateString)      \(placename)")
                }
            }
        } else {
            self.displayInfoString("\(dateString)      \(parentPath)")
        }
    }

    func displayInfoString(_ displayInfo: String)
    {
        let fullRange = NSRange(location: 0, length: displayInfo.count)
        let attributeString = NSMutableAttributedString(string: displayInfo)
        attributeString.addAttribute(NSAttributedStringKey.backgroundColor, value: NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0.75), range: fullRange)
        infoText.attributedStringValue = attributeString
    }

    func showImage(_ mediaData: MediaData) -> Double?
    {
        stopVideoPlayer()
        imageView?.image = nil
        imageView?.isHidden = false
        videoView?.isHidden = true

        Async.background {
            var nsImage: NSImage
            if let rotation = mediaData.rotation, rotation == ImageOrientation.topLeft.rawValue {
                nsImage = NSImage(byReferencing: mediaData.url)
                let imageRep = nsImage.representations[0]
                nsImage.size = NSSize(width: imageRep.pixelsWide, height: imageRep.pixelsHigh)
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
                self.imageView?.image = nsImage;
            }
        }
        return 0
    }

    func showVideo(_ mediaData: MediaData)
    {
        stopVideoPlayer()

        imageView?.isHidden = true
        imageView?.image = nil
        videoView?.isHidden = false

        videoView.player = AVPlayer(url: mediaData.url)
        let player = videoView.player!
        player.volume = Preferences.videoPlayerVolume
        player.actionAtItemEnd = .none

        player.addObserver(self, forKeyPath: "volume", options: .new, context: nil)
//        player.addObserver(self, forKeyPath: "rate", options: .New, context: nil)
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


    // MARK: view creation
    func createImageView() -> NSImageView
    {
        let textheight = infoText.frame.height
        let imageView = NSImageView(frame: (window?.contentView?.frame.offsetBy(dx: 0, dy: textheight).insetBy(dx: 0, dy: textheight))!)
        imageView.imageScaling = NSImageScaling.scaleProportionallyDown
        imageView.autoresizingMask = NSView.AutoresizingMask(rawValue: NSView.AutoresizingMask.height.rawValue
            | NSView.AutoresizingMask.width.rawValue)
        return imageView
    }

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
