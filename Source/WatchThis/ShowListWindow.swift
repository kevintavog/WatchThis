//
//

import AppKit
import Foundation

import RangicCore

class ShowListWindow : NSWindow, NSDraggingDestination
{
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation
    {
        Logger.info("Dragging entered")
        return folderPaths(sender).count > 0 ? .copy : NSDragOperation()
    }

    func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation
    {
        return folderPaths(sender).count > 0 ? .copy : NSDragOperation()
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool
    {
        let folderList = folderPaths(sender)
        Logger.info("Perform drag operation: \(folderList)")
        return true
    }

    func folderPaths(_ dragInfo: NSDraggingInfo) -> [String]
    {
        var list = [String]()

        if (dragInfo.draggingPasteboard().types?.contains(ShowListController.FilenamesPboardType) != nil) {
            if let fileArray = dragInfo.draggingPasteboard().propertyList(forType: ShowListController.FilenamesPboardType) as? [String] {
                for file in fileArray {
                    var isDirectory:ObjCBool = false
                    if FileManager.default.fileExists(atPath: file, isDirectory: &isDirectory) && isDirectory.boolValue {
                        list.append(file)
                    }
                }
            }
        }

        return list
    }
}
