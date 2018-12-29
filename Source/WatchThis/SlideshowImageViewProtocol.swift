//
//

import AppKit

protocol SlideshowImageView {

    func create(window: NSWindow?, textField: NSTextField?)
    func close()

    func windowResized(window: NSWindow?)
    var numberOfViews: UInt { get }

    func isTextTruncated(text: String, viewId: String) -> Bool
    func setText(text: String, viewId: String)

    func showImage(show: Bool, viewId: String)
    func clearImage(viewId: String)
    func setImage(image: NSImage, viewId: String)
}
