//
//

import AppKit
import Foundation

import RangicCore

class ShowListWindow : NSWindow, NSDraggingDestination
{
    func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation
    {
        Logger.info("Dragging entered")
        return folderPaths(sender).count > 0 ? .Copy : .None
    }

    func draggingUpdated(sender: NSDraggingInfo) -> NSDragOperation
    {
        return folderPaths(sender).count > 0 ? .Copy : .None
    }

    func performDragOperation(sender: NSDraggingInfo) -> Bool
    {
        let folderList = folderPaths(sender)
        Logger.info("Perform drag operation: \(folderList)")
        return true
    }

    func folderPaths(dragInfo: NSDraggingInfo) -> [String]
    {
        var list = [String]()

        if (dragInfo.draggingPasteboard().types?.contains(NSFilenamesPboardType) != nil) {
            if let fileArray = dragInfo.draggingPasteboard().propertyListForType(NSFilenamesPboardType) as? [String] {
                for file in fileArray {
                    var isDirectory:ObjCBool = false
                    if NSFileManager.defaultManager().fileExistsAtPath(file, isDirectory: &isDirectory) && isDirectory {
                        list.append(file)
                    }
                }
            }
        }

        return list
    }
}