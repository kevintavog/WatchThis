//
//

import AppKit
import Foundation

import RangicCore

import Async

class ShowListController : NSWindowController, NSWindowDelegate, SlideshowListProviderDelegate
{
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
        window!.registerForDraggedTypes([NSFilenamesPboardType])
        updateEditData()

        Notifications.addObserver(self, selector: "slideshowEnumerationCompleted:", name: Notifications.SlideshowListProvider.EnumerationCompleted, object: nil)

        Async.background {
            self.slideshowListProvider.findSavedSlideshows()
        }
    }

    func addKeyboardShorcutToMenu()
    {
        if let windowMenu = NSApp.windowsMenu {
            if let listItem = windowMenu.itemWithTitle("Watch This") {
                listItem.keyEquivalent = "0"
                listItem.keyEquivalentModifierMask = Int(NSEventModifierFlags.CommandKeyMask.rawValue)
            }

            var shortcut = 1
            for item in windowMenu.itemArray {
                if shortcut < 10 {
                    if item.title.rangeOfString("Slideshow") != nil  {
                        item.keyEquivalent = String(shortcut)
                        item.keyEquivalentModifierMask = Int(NSEventModifierFlags.CommandKeyMask.rawValue)

                        shortcut += 1
                    }
                }
            }
        }
    }

    // MARK: notifications
    func slideshowEnumerationCompleted(notification: NSNotification)
    {
        Async.main {
            self.savedTableView.reloadData()
        }
    }

    // MARK: menu handling
    @IBAction func saveEditFields(sender: AnyObject)
    {
        saveSlideshow(slideshowListProvider.editedSlideshow)
    }

    @IBAction func clearEditFields(sender: AnyObject)
    {
        slideshowListProvider.editedSlideshow.reset()
        updateEditData()
    }

    @IBAction func deleteSavedSlideshow(sender: AnyObject)
    {
    }

    @IBAction func run(sender: AnyObject)
    {
        if let selectedSlideshow = getActiveSlideshow() {

            // TODO: AND search isn't present...
            if selectedSlideshow.folderList.count < 1 {
                let alert = NSAlert()
                alert.messageText = "There are no images to show because there are no folders and no search terms in this slideshow."
                alert.alertStyle = NSAlertStyle.WarningAlertStyle
                alert.addButtonWithTitle("Close")
                alert.runModal()
                return
            }

            let slideshowController = SlideshowWindowController(windowNibName: "SlideshowWindow")
            slideshowController.window?.makeKeyAndOrderFront(self)
            slideshowController.setDataModel(selectedSlideshow, mediaList: MediaList(data: selectedSlideshow))

            slideshowControllers.append(slideshowController)

            addKeyboardShorcutToMenu()
        }
        else {
            let alert = NSAlert()
            alert.messageText = "Select a slideshow to run."
            alert.alertStyle = NSAlertStyle.WarningAlertStyle
            alert.addButtonWithTitle("Close")
            alert.runModal()
            return
        }
    }

    @IBAction func addFolder(sender: AnyObject)
    {
        let dialog = NSOpenPanel()

        dialog.canChooseFiles = false
        dialog.canChooseDirectories = true
        dialog.allowsMultipleSelection = true
        if 1 != dialog.runModal() || dialog.URLs.count < 1 {
            return
        }

        for folderUrl in dialog.URLs {
            slideshowListProvider.editedSlideshow.folderList.append(folderUrl.path!)
        }

        editFolderTableView.reloadData()
    }

    @IBAction func removeFolder(sender: AnyObject)
    {
        if editFolderTableView.selectedRow >= 0 {

            var itemsToRemove = Set<String>()
            for (_, index) in editFolderTableView.selectedRowIndexes.enumerate() {
                itemsToRemove.insert(slideshowListProvider.editedSlideshow.folderList[index])
            }

            let newFolders = slideshowListProvider.editedSlideshow.folderList.filter( { f in !itemsToRemove.contains(f) })

            slideshowListProvider.editedSlideshow.folderList = newFolders
            editFolderTableView.reloadData()
        }
    }

    @IBAction func slideDurationChanged(sender: AnyObject)
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
            Logger.log("Not implemented yet...: search tab")
            return nil

        default:
            Logger.log("Unexpected tab identifier: \(tabView.selectedTabViewItem?.identifier)")
            return nil
        }
    }

    // MARK: table view data
    func numberOfRowsInTableView(tv: NSTableView) -> Int
    {
        switch tv.tag {
        case 0:
            return slideshowListProvider.editedSlideshow.folderList.count
        case 1:
            return slideshowListProvider.savedSlideshows.count
        default:
            Logger.log("Unknown tag: \(tv.tag)")
            return 0
        }
    }

    func tableView(tv: NSTableView, objectValueForTableColumn: NSTableColumn?, row: Int) -> String
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

    // MARK: NSWindowDelegate
    func windowShouldClose(sender: AnyObject) -> Bool
    {
        return slideshowListProvider.canClose()
    }

    // MARK: SlideshowListProviderDelegate
    func saveSlideshow(slideshow: SlideshowData) -> Bool
    {
        if slideshow.folderList.count < 1 {
            let alert = NSAlert()
            alert.messageText = "Add a folder before saving."
            alert.alertStyle = NSAlertStyle.WarningAlertStyle
            alert.addButtonWithTitle("Close")
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
            alert.alertStyle = NSAlertStyle.WarningAlertStyle
            alert.addButtonWithTitle("Close")
            alert.runModal()
        }

        return false
    }
    
    func wantToSaveEditedSlideshow() -> WtButtonId
    {
        let alert = NSAlert()
        alert.messageText = "Do you want to save changes to the Edited slideshow?"
        alert.alertStyle = NSAlertStyle.WarningAlertStyle
        alert.addButtonWithTitle("Yes")
        alert.addButtonWithTitle("No")
        alert.addButtonWithTitle("Cancel")

        let response = alert.runModal()
        switch response {
        case NSAlertFirstButtonReturn:
            return WtButtonId.No
        default:
            return WtButtonId.Cancel
        }
    }

    func getUniqueNameFromUser() -> String?
    {
        let question = NSAlert()
        question.messageText = "Enter a name for this slideshow"
        question.alertStyle = NSAlertStyle.InformationalAlertStyle
        question.addButtonWithTitle("OK")
        question.addButtonWithTitle("Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        question.accessoryView = textField
        question.window.initialFirstResponder = textField

        repeat {
            let response = question.runModal()
            if response != NSAlertFirstButtonReturn {
                return nil
            }

            if textField.stringValue.characters.count == 0 {
                continue
            }

            let name = textField.stringValue.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())

            // TODO: Case-insensitive search
            let matchingNames = slideshowListProvider.savedSlideshows.filter(
                { s in !(s.filename == slideshowListProvider.editedSlideshow.filename)
                    && !(s.name == name)
            } )

            if matchingNames.count > 0 {
                let alert = NSAlert()
                alert.messageText = "The name '\(name)' is already used - choose a unique name."
                alert.alertStyle = NSAlertStyle.WarningAlertStyle
                alert.addButtonWithTitle("Close")
                alert.runModal()
                continue
            }
            
            return name
            
        } while true
    }
}