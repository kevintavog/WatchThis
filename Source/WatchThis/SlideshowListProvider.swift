//
//

import AppKit
import Foundation

import RangicCore

class SlideshowListProvider
{
    var savedSlideshows = [SlideshowData]()
    var editedSlideshow = SlideshowData()


    /// Starts enumerating saved slideshows - this is a blocking call. Fires the 
    /// SlideshowListProvider.EnumerationCompleted notification on completion
    func findSavedSlideshows()
    {
        var foundSlideshows = [SlideshowData]()
        if NSFileManager.defaultManager().fileExistsAtPath(Preferences.slideshowFolder) {
            if let urlList = getFiles(Preferences.slideshowFolder) {
                for url in urlList {
                    do {
                        let slideshowData = try SlideshowData.load(url.path!)
                        foundSlideshows.append(slideshowData)
                    }
                    catch let error {
                        Logger.log("Failed loading \(error)")
                    }
                }
            }
        }

        savedSlideshows = foundSlideshows
        Notifications.postNotification(Notifications.SlideshowListProvider.EnumerationCompleted, object: self, userInfo: nil)
    }

    func canClose() -> Bool
    {
        // If it hasn't been saved yet, save it as the lastEdited so it can be loaded on the next run.
        if editedSlideshow.filename == nil {
            editedSlideshow.filename = Preferences.lastEditedFilename
            editedSlideshow.name = ""

            do {
                try editedSlideshow.save()
            } catch let error as NSError {
                Logger.log("Error saving last edited: \(error)")
            }
            editedSlideshow.filename = nil
            return true
        }
        else {
            Logger.log("Save edited if changed (save with a real name, change it - end up here)")
        }

        return true
    }

    private func getFiles(folderName:String) -> [NSURL]?
    {
        do {
            let urlList = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(
                NSURL(fileURLWithPath: folderName),
                includingPropertiesForKeys: nil,
                options:NSDirectoryEnumerationOptions.SkipsHiddenFiles)

            return urlList.filter( {
                if let ext = $0.pathExtension {
                    return ext == SlideshowData.FileExtension
                }
                else {
                    return false
                }
            })
        }
        catch {
            return nil
        }
    }
}