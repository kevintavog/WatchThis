//
//

import AppKit
import Foundation

import RangicCore


protocol SlideshowListProviderDelegate
{
    func wantToSaveEditedSlideshow() -> WtButtonId
    func saveSlideshow(_ slideshow: SlideshowData) -> Bool
}

class SlideshowListProvider
{
    var savedSlideshows = [SlideshowData]()
    var editedSlideshow = SlideshowData()
    var delegate: SlideshowListProviderDelegate? = nil


    init()
    {
        if FileManager.default.fileExists(atPath: Preferences.lastEditedFilename) {
            do {
                editedSlideshow = try SlideshowData.load(Preferences.lastEditedFilename)
            } catch let error {
                Logger.error("Error loading last edited: \(error)")
            }
        }
    }

    /// Starts enumerating saved slideshows - this is a blocking call. Fires the 
    /// SlideshowListProvider.EnumerationCompleted notification on completion
    func findSavedSlideshows()
    {
        var foundSlideshows = [SlideshowData]()
        if FileManager.default.fileExists(atPath: Preferences.slideshowFolder) {
            if let urlList = getFiles(Preferences.slideshowFolder) {
                for url in urlList {
                    do {
                        let slideshowData = try SlideshowData.load(url.path)
                        foundSlideshows.append(slideshowData)
                    }
                    catch let error {
                        Logger.error("Failed loading \(error)")
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
                Logger.error("Error saving last edited: \(error)")
            }
            editedSlideshow.filename = nil
            return true
        }
        
        return saveIfChanged()
    }

    // If the editedSlideshow has changes, ask the user if they want to save changes. Returns true
    // if the caller can continue, false otherwise.
    // True is returned if
    // 	1) There are no changes to editedSlideshow - or there aren't 'worthwhile' changes
    // 	2) The user does NOT want to save
    // 	3) The user wants to save and the save succeeds
    // False is returned if there are worthwhile changes and:
    // 	1) The user canceled the 'want to save' question
    // 	2) The user canceled the request for the save name
    // 	3) The save failed
    fileprivate func saveIfChanged() -> Bool
    {
        if editedSlideshow.hasChanged && editedSlideshow.folderList.count > 0 {
            let response = delegate?.wantToSaveEditedSlideshow()
            switch response! {
            case .cancel:
                return false
            case .no:
                return true
            case .yes:
                return (delegate?.saveSlideshow(editedSlideshow))!
            default:
                return false
            }
        }
        return true
    }

    fileprivate func getFiles(_ folderName:String) -> [URL]?
    {
        do {
            let urlList = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: folderName),
                includingPropertiesForKeys: nil,
                options:FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)

            return urlList.filter( {
                return $0.pathExtension == Preferences.SlideshowFileExtension
            })
        }
        catch {
            return nil
        }
    }
}
