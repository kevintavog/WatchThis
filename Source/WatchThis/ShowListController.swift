//
//

import AppKit
import Foundation

import RangicCore

import Async

class ShowListController : NSWindowController
{
    let slideshowProvider = SlideshowListProvider()
    var slideshowControllers = [SlideshowWindowController]()

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
        window!.registerForDraggedTypes([NSFilenamesPboardType])
        updateEditData()

        Notifications.addObserver(self, selector: "slideshowEnumerationCompleted:", name: Notifications.SlideshowListProvider.EnumerationCompleted, object: nil)

        Async.background {
            self.slideshowProvider.findSavedSlideshows()
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
        if slideshowProvider.editedSlideshow.folderList.count < 1 {
            let alert = NSAlert()
            alert.messageText = "Add a folder before saving."
            alert.alertStyle = NSAlertStyle.WarningAlertStyle
            alert.addButtonWithTitle("Close")
            alert.runModal()
            return
        }

        let name = getUniqueNameFromUser()
        if name == nil {
            return
        }

        // Come up with a reasonable filename (unique name minus file system characters)
        slideshowProvider.editedSlideshow.name = name
        slideshowProvider.editedSlideshow.filename = SlideshowData.getFilenameForName(name!)
        do {
            try slideshowProvider.editedSlideshow.save()
        } catch let error as SlideshowData.FileError {
            let alert = NSAlert()
            alert.messageText = "There was an error saving the slideshow: \(error)."
            alert.alertStyle = NSAlertStyle.WarningAlertStyle
            alert.addButtonWithTitle("Close")
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "There was an error saving the slideshow."
            alert.alertStyle = NSAlertStyle.WarningAlertStyle
            alert.addButtonWithTitle("Close")
            alert.runModal()
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
            let matchingNames = slideshowProvider.savedSlideshows.filter(
                { s in !(s.filename == slideshowProvider.editedSlideshow.filename)
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

    @IBAction func clearEditFields(sender: AnyObject)
    {
        slideshowProvider.editedSlideshow.reset()
        updateEditData()
    }

    @IBAction func deleteSavedSlideshow(sender: AnyObject)
    {
    }

    @IBAction func run(sender: AnyObject)
    {
        let slideshowController = SlideshowWindowController()
        NSBundle.mainBundle().loadNibNamed("SlideshowWindow", owner: slideshowController, topLevelObjects: nil)
        slideshowController.window?.makeKeyAndOrderFront(self)

        slideshowControllers.append(slideshowController)
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
            slideshowProvider.editedSlideshow.folderList.append(folderUrl.path!)
        }

        editFolderTableView.reloadData()
    }

    @IBAction func removeFolder(sender: AnyObject)
    {
        if editFolderTableView.selectedRow >= 0 {

            var itemsToRemove = Set<String>()
            for (_, index) in editFolderTableView.selectedRowIndexes.enumerate() {
                itemsToRemove.insert(slideshowProvider.editedSlideshow.folderList[index])
            }

            let newFolders = slideshowProvider.editedSlideshow.folderList.filter( { f in !itemsToRemove.contains(f) })

            slideshowProvider.editedSlideshow.folderList = newFolders
            editFolderTableView.reloadData()
        }
    }

    @IBAction func slideDurationChanged(sender: AnyObject)
    {
        slideshowProvider.editedSlideshow.slideSeconds = slideDurationStepper.doubleValue
        updateEditData()
    }

    func updateEditData()
    {
        slideDurationText.doubleValue = slideshowProvider.editedSlideshow.slideSeconds
        slideDurationStepper.doubleValue = slideshowProvider.editedSlideshow.slideSeconds
    }

    // MARK: table view data
    func numberOfRowsInTableView(tv: NSTableView) -> Int
    {
        switch tv.tag {
        case 0:
            return slideshowProvider.editedSlideshow.folderList.count
        case 1:
            return slideshowProvider.savedSlideshows.count
        default:
            Logger.log("Unknown tag: \(tv.tag)")
            return 0
        }
    }

    func tableView(tv: NSTableView, objectValueForTableColumn: NSTableColumn?, row: Int) -> String
    {
        switch tv.tag {
        case 0:
            return slideshowProvider.editedSlideshow.folderList[row]
        case 1:
            return slideshowProvider.savedSlideshows[row].name ?? ""
        default:
            return ""
        }
    }
}