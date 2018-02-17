//

import AppKit

class SingleSlideshowImageView : SlideshowImageView {
    var imageView: NSImageView?


    func create(window: NSWindow?, textHeight: CGFloat) {
        imageView = NSImageView(frame: (window?.contentView?.frame.offsetBy(dx: 0, dy: textHeight).insetBy(dx: 0, dy: textHeight))!)
        imageView?.imageScaling = NSImageScaling.scaleProportionallyDown
        imageView?.autoresizingMask = NSView.AutoresizingMask(rawValue: NSView.AutoresizingMask.height.rawValue
            | NSView.AutoresizingMask.width.rawValue)

        window?.contentView?.addSubview(imageView!, positioned: NSWindow.OrderingMode.below, relativeTo: window?.contentView?.subviews[0])
    }

    func hide() {
        imageView?.isHidden = true
    }

    func show() {
        imageView?.isHidden = false
    }

    func clearImage() {
        imageView?.image = nil
    }

    func setImage(image: NSImage) {
        imageView?.image = image
    }
}
