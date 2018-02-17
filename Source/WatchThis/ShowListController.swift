//
//

import AppKit
import Foundation

import RangicCore

import Async

class ShowListController : NSWindowController, NSWindowDelegate, SlideshowListProviderDelegate
{
    // In Swift 4, 'NSPasteboard.PasteboardType.fileURL' is available, but seems to be OSX 10.13 only - use this as a workaround
    static let FilenamesPboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    

    
    var slideshowListProvider = SlideshowListProvider()
    var slideshowControllers = [SlideshowWindowController]()

    @IBOutlet weak var tabView: NSTabView!
    @IBOutlet weak var editFilesTabItem: NSTabViewItem!
    @IBOutlet weak var editFolderTableView: NSTableView!
    @IBOutlet weak var savedTabItem: NSTabViewItem!
    @IBOutlet weak var savedTableView: NSTableView!
    @IBOutlet weak var slideDurationStepper: NSStepper!
    @IBOutlet weak var slideDurationText: NSTextField!



    // MARK: initialization
    override func awakeFromNib()
    {
        super.awakeFromNib()

        slideshowListProvider.delegate = self
        window!.registerForDraggedTypes([ShowListController.FilenamesPboardType])
        updateEditData()

        Notifications.addObserver(self, selector: #selector(ShowListController.slideshowEnumerationCompleted(_:)), name: Notifications.SlideshowListProvider.EnumerationCompleted, object: nil)

        Async.background {
            self.slideshowListProvider.findSavedSlideshows()
        }
    }

    func addKeyboardShorcutToMenu()
    {
        if let windowMenu = NSApp.windowsMenu {
            if let listItem = windowMenu.item(withTitle: "Watch This") {
                listItem.keyEquivalent = "0"
                listItem.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: UInt(Int(NSEvent.ModifierFlags.command.rawValue)))
            }

            var shortcut = 1
            for item in windowMenu.items {
                if shortcut < 10 {
                    if item.title.range(of: "Slideshow") != nil  {
                        item.keyEquivalent = String(shortcut)
                        item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: UInt(Int(NSEvent.ModifierFlags.command.rawValue)))

                        shortcut += 1
                    }
                }
            }
        }
    }

    // MARK: notifications
    @objc func slideshowEnumerationCompleted(_ notification: Notification)
    {
        Async.main {
            self.savedTableView.reloadData()
        }
    }

    // MARK: menu handling
    @IBAction func saveEditFields(_ sender: AnyObject)
    {
        let _ = saveSlideshow(slideshowListProvider.editedSlideshow)
    }

    @IBAction func clearEditFields(_ sender: AnyObject)
    {
        slideshowListProvider.editedSlideshow.reset()
        updateEditData()
    }

    @IBAction func deleteSavedSlideshow(_ sender: AnyObject)
    {
    }

    @IBAction func run(_ sender: AnyObject)
    {
        if let selectedSlideshow = getActiveSlideshow() {

            if selectedSlideshow.folderList.count < 1 && selectedSlideshow.searchQuery == nil {
                let alert = NSAlert()
                alert.messageText = "There are no images to show because there are no folders and no search terms in this slideshow."
                alert.alertStyle = NSAlert.Style.warning
                alert.addButton(withTitle: "Close")
                alert.runModal()
                return
            }

            let slideshowController = SlideshowWindowController(windowNibName: NSNib.Name(rawValue: "SlideshowWindow"))
            slideshowController.window?.makeKeyAndOrderFront(self)
            slideshowController.setDataModel(selectedSlideshow, mediaList: MediaList(data: selectedSlideshow))

            slideshowControllers.append(slideshowController)

            addKeyboardShorcutToMenu()
        }
        else {
            let alert = NSAlert()
            alert.messageText = "Select a slideshow to run."
            alert.alertStyle = NSAlert.Style.warning
            alert.addButton(withTitle: "Close")
            alert.runModal()
            return
        }
    }

    @IBAction func addFolder(_ sender: AnyObject)
    {
        let dialog = NSOpenPanel()

        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        dialog.allowsMultipleSelection = true
        if 1 != dialog.runModal().rawValue || dialog.urls.count < 1 {
            return
        }

        for folderUrl in dialog.urls {
            slideshowListProvider.editedSlideshow.folderList.append(folderUrl.path)
        }

        editFolderTableView.reloadData()
    }

    @IBAction func removeFolder(_ sender: AnyObject)
    {
        if editFolderTableView.selectedRow >= 0 {

            var itemsToRemove = Set<String>()
            for (_, index) in editFolderTableView.selectedRowIndexes.enumerated() {
                itemsToRemove.insert(slideshowListProvider.editedSlideshow.folderList[index])
            }

            let newFolders = slideshowListProvider.editedSlideshow.folderList.filter( { f in !itemsToRemove.contains(f) })

            slideshowListProvider.editedSlideshow.folderList = newFolders
            editFolderTableView.reloadData()
        }
    }

    @IBAction func slideDurationChanged(_ sender: AnyObject)
    {
        slideshowListProvider.editedSlideshow.slideSeconds = slideDurationStepper.doubleValue
        updateEditData()
    }

    func updateEditData()
    {
        slideDurationText.doubleValue = slideshowListProvider.editedSlideshow.slideSeconds
        slideDurationStepper.doubleValue = slideshowListProvider.editedSlideshow.slideSeconds
    }

    func getActiveSlideshow() -> SlideshowData?
    {
        switch tabView.selectedTabViewItem?.identifier as! String {
        case "Saved":
            if savedTableView.selectedRow < 0 {
                return nil
            }
            return slideshowListProvider.savedSlideshows[savedTableView.selectedRow]

        case "EditFiles":
            return slideshowListProvider.editedSlideshow

        case "EditSearch":
            Logger.error("Not implemented yet...: search tab")
            return nil

        default:
            Logger.error("Unexpected tab identifier: \(String(describing: tabView.selectedTabViewItem?.identifier))")
            return nil
        }
    }

    // MARK: table view data
    @objc
    func numberOfRowsInTableView(_ tv: NSTableView) -> Int
    {
        switch tv.tag {
        case 0:
            return slideshowListProvider.editedSlideshow.folderList.count
        case 1:
            return slideshowListProvider.savedSlideshows.count
        default:
            Logger.error("Unknown tag: \(tv.tag)")
            return 0
        }
    }

    @objc
    func tableView(_ tv: NSTableView, objectValueForTableColumn: NSTableColumn?, row: Int) -> String
    {
        switch tv.tag {
        case 0:
            return slideshowListProvider.editedSlideshow.folderList[row]
        case 1:
            return slideshowListProvider.savedSlideshows[row].name ?? ""
        default:
            return ""
        }
    }

    func canClose() -> Bool {
        return slideshowListProvider.canClose()
    }
    
    // MARK: NSWindowDelegate
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return canClose()
    }

    // MARK: SlideshowListProviderDelegate
    func saveSlideshow(_ slideshow: SlideshowData) -> Bool
    {
        if slideshow.folderList.count < 1 {
            let alert = NSAlert()
            alert.messageText = "Add a folder before saving."
            alert.alertStyle = NSAlert.Style.warning
            alert.addButton(withTitle: "Close")
            alert.runModal()
            return false
        }

        let name = getUniqueNameFromUser()
        if name == nil {
            return false
        }

        // Come up with a reasonable filename (unique name minus file system characters)
        slideshow.name = name
        slideshow.filename = SlideshowData.getFilenameForName(name!)
        do {
            try slideshow.save()
            return true
        } catch let error {
            let alert = NSAlert()
            alert.messageText = "There was an error saving the slideshow: \(error)."
            alert.alertStyle = NSAlert.Style.warning
            alert.addButton(withTitle: "Close")
            alert.runModal()
        }

        return false
    }
    
    func wantToSaveEditedSlideshow() -> WtButtonId
    {
        let alert = NSAlert()
        alert.messageText = "Do you want to save changes to the Edited slideshow?"
        alert.alertStyle = NSAlert.Style.warning
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        switch response {
        case NSApplication.ModalResponse.alertFirstButtonReturn:
            return WtButtonId.no
        default:
            return WtButtonId.cancel
        }
    }

    func getUniqueNameFromUser() -> String?
    {
        let question = NSAlert()
        question.messageText = "Enter a name for this slideshow"
        question.alertStyle = NSAlert.Style.informational
        question.addButton(withTitle: "OK")
        question.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        question.accessoryView = textField
        question.window.initialFirstResponder = textField

        repeat {
            let response = question.runModal()
            if response != NSApplication.ModalResponse.alertFirstButtonReturn {
                return nil
            }

            if textField.stringValue.count == 0 {
                continue
            }

            let name = textField.stringValue.trimmingCharacters(in: CharacterSet.whitespaces)

            // TODO: Case-insensitive search
            let matchingNames = slideshowListProvider.savedSlideshows.filter(
                { s in !(s.filename == slideshowListProvider.editedSlideshow.filename)
                    && !(s.name == name)
            } )

            if matchingNames.count > 0 {
                let alert = NSAlert()
                alert.messageText = "The name '\(name)' is already used - choose a unique name."
                alert.alertStyle = NSAlert.Style.warning
                alert.addButton(withTitle: "Close")
                alert.runModal()
                continue
            }
            
            return name
            
        } while true
    }
}
