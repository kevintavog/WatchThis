//
//

import AppKit
import RangicCore

class MultiSlideshowImageView : SlideshowImageView {
    var views = [ViewPanel(), ViewPanel(), ViewPanel(), ViewPanel()]

    var numberOfViews: UInt { get { return UInt(views.count) } }


    func isTextTruncated(text: String, viewId: String) -> Bool {
        if let vp = panelFromId(viewId) {
            let tf = vp.infoText!
            let attrStr = NSAttributedString(string: text, attributes: [.font: tf.font!])
            return attrStr.size().width > tf.frame.width
        }
        return false
    }

    func setText(text: String, viewId: String) {
        if let vp = panelFromId(viewId) {
            vp.infoText!.stringValue = text
        } else {
            // A new id - replace an existing panel
            let v = oldestPanel()
            v?.setId(viewId)
            v?.infoText!.stringValue = text
            v?.imageView?.image = nil
        }
    }


    func showImage(show: Bool, viewId: String) {
        if let vp = panelFromId(viewId) {
            vp.imageView!.isHidden = !show
        }
    }

    func clearImage(viewId: String) {
        if let vp = panelFromId(viewId) {
            vp.imageView!.image = nil
        }
    }
    
    func setImage(image: NSImage, viewId: String) {
        if let vp = panelFromId(viewId) {
            vp.imageView!.image = image
        } else {
            Logger.error("show image, viewId not found \(viewId)")
        }
    }

    func windowResized(window: NSWindow?) {
        for v in views {
            v.resize(window)
        }
    }

    func create(window: NSWindow?, textField: NSTextField?) {
        views[0].create(0, window, textField)
        views[1].create(1, window, textField)
        views[2].create(2, window, textField)
        views[3].create(3, window, textField)
    }

    func close() {
        for v in views {
            v.close()
        }
    }

    func panelFromId(_ viewId: String) -> ViewPanel? {
        for vp in views {
            if vp.id == viewId {
                return vp
            }
        }
        return nil
    }

    func oldestPanel() -> ViewPanel? {
        let sorted = views.sorted( by: { (v1:ViewPanel, v2:ViewPanel) -> Bool in
            if v1.lastUpdated == v2.lastUpdated {
                return v1.index < v2.index
            }
            return v1.lastUpdated.compare(v2.lastUpdated as Date) == ComparisonResult.orderedAscending })
        return sorted.first
    }
}
