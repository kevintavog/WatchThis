//
//

import AppKit
import RangicCore

class ViewPanel {
    var imageView: NSImageView? = nil
    var infoText: NSTextField? = nil
    var index: UInt = 0
    var textHeight: CGFloat = 0
    var id: String = ""
    var lastUpdated = Date()
    let border: CGFloat = 4
    let backgroundColor = CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)


    public var description: String { return "ViewPanel \(index), \(lastUpdated.timeIntervalSince1970), \(id)" }


    func create(_ idx: UInt, _ window: NSWindow?, _ textField: NSTextField?) {
        textHeight = textField!.frame.height
        index = idx
        imageView = createView(window: window, frame: imageFrameForIndex(window, index))
        infoText = createTextField(window: window, textField: textField, frame: textFrameForIndex(window, index))
    }

    func close() {
        imageView?.removeFromSuperview()
        infoText?.removeFromSuperview()
    }

    func setId(_ id: String) {
        self.id = id
        self.lastUpdated = Date()
    }

    func resize(_ window: NSWindow?) {
        imageView?.frame = imageFrameForIndex(window, index)
        infoText?.frame = textFrameForIndex(window, index)
    }

    func imageFrameForIndex(_ window: NSWindow?, _ viewIndex: UInt) -> NSRect {
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

    func textFrameForIndex(_ window: NSWindow?, _ viewIndex: UInt) -> NSRect {
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

    func createView(window: NSWindow?, frame: NSRect) -> NSImageView {
        let imageView = NSImageView(frame: frame)

        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = backgroundColor

        imageView.imageScaling = NSImageScaling.scaleProportionallyDown
        imageView.autoresizingMask = NSView.AutoresizingMask(rawValue: NSView.AutoresizingMask.height.rawValue
            | NSView.AutoresizingMask.width.rawValue)

        window?.contentView?.addSubview(imageView, positioned: NSWindow.OrderingMode.below, relativeTo: window?.contentView)
        
        return imageView
    }

    func createTextField(window: NSWindow?, textField: NSTextField?, frame: NSRect) -> NSTextField {
        let infoText = NSTextField(frame: frame)

        infoText.isEditable = (textField?.isEditable)!
        infoText.isSelectable = (textField?.isSelectable)!
        infoText.isBordered = (textField?.isBordered)!
        infoText.textColor = textField?.textColor
        infoText.backgroundColor = NSColor(cgColor: backgroundColor)
        infoText.font = textField?.font
        infoText.alignment = textField!.alignment
        infoText.stringValue = ""
        infoText.isHidden = false

        window?.contentView?.addSubview(infoText, positioned: NSWindow.OrderingMode.below, relativeTo: window?.contentView?.subviews[0])

        return infoText
    }
}
