//
//

import AppKit

class SlideshowWindowController : NSWindowController
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


    // MARK: initialization
    override func awakeFromNib()
    {
        super.awakeFromNib()
        window!.backgroundColor = NSColor.blackColor()

        infoText.stringValue = ""
    }

    func updateUiState()
    {

    }
}