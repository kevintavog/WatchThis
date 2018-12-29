//

import AppKit

class SingleSlideshowImageView : SlideshowImageView {
    var imageView: NSImageView?
    var infoText: NSTextField?

    var numberOfViews: UInt { get { return 1 } }


    func isTextTruncated(text: String, viewId: String) -> Bool {
        let attrStr = NSAttributedString(string: text, attributes: [.font: infoText!.font!])
        
        return attrStr.size().width > infoText!.frame.width
    }
    
    func setText(text: String, viewId: String) {
        infoText?.stringValue = text
    }


    func showImage(show: Bool, viewId: String) {
        imageView?.isHidden = !show
    }

    func clearImage(viewId: String) {
        imageView?.image = nil
    }

    func setImage(image: NSImage, viewId: String) {
        imageView?.image = image
    }

    func windowResized(window: NSWindow?) {
    }

    func create(window: NSWindow?, textField: NSTextField?) {
        let textHeight = (textField?.frame.height)!
        infoText = NSTextField(frame: NSMakeRect(0, 0, (window?.contentView?.frame.width)!, textHeight))
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
        
        imageView = NSImageView(frame: (window?.contentView?.frame.offsetBy(dx: 0, dy: textHeight).insetBy(dx: 0, dy: textHeight))!)
        imageView?.imageScaling = NSImageScaling.scaleProportionallyDown
        imageView?.autoresizingMask = NSView.AutoresizingMask(rawValue: NSView.AutoresizingMask.height.rawValue
            | NSView.AutoresizingMask.width.rawValue)
        
        window?.contentView?.addSubview(imageView!, positioned: NSWindow.OrderingMode.below, relativeTo: window?.contentView?.subviews[0])
    }

    func close() {
        imageView?.removeFromSuperview()
        infoText?.removeFromSuperview()
    }
}
