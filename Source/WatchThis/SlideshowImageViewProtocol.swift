//
//

import AppKit

protocol SlideshowImageView {
    func create(window: NSWindow?, textHeight: CGFloat)
    func hide()
    func show()
    func clearImage()
    func setImage(image: NSImage)
}
