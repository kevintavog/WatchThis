import AppKit
import AVFoundation
import AVKit
import RangicCore
import Async

class MediaContainer {
    let numPanels: UInt
    let panels: [MediaPanel]

    public init(numPanels: UInt) {
        self.numPanels = numPanels
        switch numPanels {
        case 1:
            panels = [MediaPanel(0, 0)]
            break
        case 4:
            panels = [MediaPanel(0, 4), MediaPanel(1, 4), MediaPanel(2, 4), MediaPanel(3, 4)]
            break
        default:
            panels = []
        }
    }

    func create(window: NSWindow?, textField: NSTextField?) {
        for idx in 0..<panels.count {
            panels[idx].create(numPanels, UInt(idx), window, textField)
        }
    }

    func close() {
        for p in panels {
            p.close()
        }
    }

    func show(mediaData: MediaData) {
        oldestPanel().show(mediaData: mediaData)
    }

    func resize(_ window: NSWindow?) {
        for idx in 0..<panels.count {
            panels[idx].resize(numPanels, window, UInt(idx))
        }
    }

    func oldestPanel() -> MediaPanel {
        let sorted = panels.sorted( by: { (v1:MediaPanel, v2:MediaPanel) -> Bool in
            if v1.lastUpdated == v2.lastUpdated {
                return v1.index < v2.index
            }
            return v1.lastUpdated.compare(v2.lastUpdated as Date) == ComparisonResult.orderedAscending })
        return sorted.first!
    }
}

class MediaPanel {
    let index: Int
    let border: CGFloat
    var videoView: AVPlayerView!
    var imageView: NSImageView?
    var infoText: NSTextField? = nil
    var textHeight: CGFloat = 0
    var lastUpdated = Date()

    init(_ index: Int, _ border: Int) {
        self.index = index
        self.border = CGFloat(border)
    }

    func show(mediaData: MediaData) {
        self.lastUpdated = Date()
        switch mediaData.type! {
        case .image:
            displayInfo(mediaData)
            let _ = showImage(mediaData)
        case .video:
            displayInfo(mediaData)
            showVideo(mediaData)
        default:
            Logger.error("Unhandled media type: \(mediaData.type!)")
        }
    }

    func showImage(_ mediaData: MediaData) {
        videoView?.isHidden = true
        videoView?.player = nil
        imageView?.image = nil
        imageView?.isHidden = false

        Async.background {
            var nsImage: NSImage
            if let rotation = mediaData.rotation, rotation == ImageOrientation.topLeft.rawValue {
                nsImage = NSImage(byReferencing: mediaData.url)
                if nsImage.representations.count > 0 {
                    let imageRep = nsImage.representations[0]
                    nsImage.size = NSSize(width: imageRep.pixelsWide, height: imageRep.pixelsHigh)
                } else {
                    Logger.error("Failed loading '\(mediaData.url!.absoluteString)'")
//                    self.nextImage(self)
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
                self.imageView?.image = nsImage
            }
        }
    }

    func showVideo(_ mediaData: MediaData) {
        let player = AVPlayer(url: mediaData.url)
        player.volume = Preferences.videoPlayerVolume
        player.actionAtItemEnd = .none
        
//        player.addObserver(self, forKeyPath: "volume", options: .new, context: nil)
//        Notifications.addObserver(self, selector: #selector(SlideshowWindowController.videoDidEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime.rawValue, object: player.currentItem)

        videoView?.player = player

        imageView?.isHidden = true
        videoView?.isHidden = false
        videoView?.player?.play()
    }

    //  MARK: show image/video
    func displayInfo(_ mediaData: MediaData) {
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
        var level = 1
        var info = displayInfoAttempt(mediaData, missingLocation, level)
        while level < 4 {
            if !isTextTruncated(text: info) {
                break
            }
            level += 1
            info = displayInfoAttempt(mediaData, missingLocation, level)
        }

        infoText!.stringValue = info
    }

    func create(_ numPanels: UInt, _ index: UInt, _ window: NSWindow?, _ textField: NSTextField?) {
        textHeight = textField!.frame.height
        createVideoView(window: window, frame: mediaFrameForIndex(window, index, numPanels))
        createImageView(window: window, frame: mediaFrameForIndex(window, index, numPanels))
        createTextField(window: window, textField: textField, frame: textFrameForIndex(window, index, numPanels))
    }

    func close() {
        videoView?.player?.pause()
        videoView?.player = nil
        imageView?.removeFromSuperview()
        infoText?.removeFromSuperview()
    }

    func createImageView(window: NSWindow?, frame: NSRect) {
        imageView = NSImageView(frame: frame)
        imageView?.imageScaling = NSImageScaling.scaleProportionallyDown
        imageView?.autoresizingMask = NSView.AutoresizingMask(rawValue: NSView.AutoresizingMask.height.rawValue
            | NSView.AutoresizingMask.width.rawValue)

        window?.contentView?.addSubview(imageView!, positioned: NSWindow.OrderingMode.below, relativeTo: window?.contentView?.subviews[0])
    }

    func createVideoView(window: NSWindow?, frame: NSRect) {
        videoView = AVPlayerView(frame: frame)
        videoView.autoresizingMask = NSView.AutoresizingMask(rawValue: NSView.AutoresizingMask.height.rawValue
            | NSView.AutoresizingMask.width.rawValue)
        videoView.controlsStyle = .none
        videoView.showsFrameSteppingButtons = true
        window?.contentView?.addSubview(videoView, positioned: NSWindow.OrderingMode.below, relativeTo: window?.contentView)
    }

    func createTextField(window: NSWindow?, textField: NSTextField?, frame: NSRect) {
        infoText = NSTextField(frame: frame)
        infoText?.autoresizingMask = NSView.AutoresizingMask(rawValue: NSView.AutoresizingMask.width.rawValue)
        window?.contentView?.addSubview(infoText!, positioned: NSWindow.OrderingMode.below, relativeTo: window?.contentView?.subviews[0])

        infoText?.isEditable = (textField?.isEditable)!
        infoText?.isSelectable = (textField?.isSelectable)!
        infoText?.isBordered = (textField?.isBordered)!
        infoText?.textColor = textField?.textColor
        infoText?.backgroundColor = textField?.backgroundColor
        infoText?.font = textField?.font
        infoText?.stringValue = ""
        infoText?.isHidden = false
    }

    func resize(_ numPanels: UInt,_ window: NSWindow?, _ index: UInt) {
        videoView?.frame = mediaFrameForIndex(window, index, numPanels)
        imageView?.frame = mediaFrameForIndex(window, index, numPanels)
        infoText?.frame = textFrameForIndex(window, index, numPanels)
    }

    func mediaFrameForIndex(_ window: NSWindow?, _ viewIndex: UInt, _ numPanels: UInt) -> NSRect {
        if numPanels == 1 {
            return window!.contentView!.frame.offsetBy(dx: 0, dy: textHeight).insetBy(dx: 0, dy: textHeight)
        }

        let panelWidth = (window?.contentView?.frame.width)! / 2
        let panelHeight = (window?.contentView?.frame.height)! / 2
        let imageHeight = panelHeight - textHeight - border
        let imageWidth = panelWidth - border

        switch viewIndex {
        case 0:
            return NSMakeRect(0, panelHeight + textHeight + border, imageWidth, imageHeight)
        case 1:
            return NSMakeRect(panelWidth + border, panelHeight + textHeight + border, imageWidth, imageHeight)
        case 2:
            return NSMakeRect(0, textHeight, imageWidth, imageHeight)
        case 3:
            return NSMakeRect(panelWidth + border, textHeight, imageWidth, imageHeight)
        default:
            return NSMakeRect(0, 0, 0, 0)
        }
    }

    func textFrameForIndex(_ window: NSWindow?, _ viewIndex: UInt, _ numPanels: UInt) -> NSRect {
        if numPanels == 1 {
            return window!.contentView!.frame
        }

        let panelWidth = (window?.contentView?.frame.width)! / 2
        let panelHeight = (window?.contentView?.frame.height)! / 2
        let textWidth = panelWidth - border

        switch viewIndex {
        case 0:
            return NSMakeRect(0, panelHeight + border, textWidth, textHeight)
        case 1:
            return NSMakeRect(panelWidth + border, panelHeight + border, textWidth, textHeight)
        case 2:
            return NSMakeRect(0, 0, textWidth, textHeight)
        case 3:
            return NSMakeRect(panelWidth + border, 0, textWidth, textHeight)
        default:
            return NSMakeRect(0, 0, 0, 0)
        }
    }

    func isTextTruncated(text: String) -> Bool {
        let attrStr = NSAttributedString(string: text, attributes: [.font: infoText!.font!])
        return attrStr.size().width > infoText!.frame.width
    }
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
