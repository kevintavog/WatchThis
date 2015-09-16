//
//

import Foundation
import RangicCore

class Preferences : BasePreferences
{
    static private let SlideshowFolderKey = "SlideshowFolder"
    static private let LastEditedFilenameKey = "LastEditedFilename"

    static func setMissingDefaults()
    {
        let appSupportFolder = NSFileManager.defaultManager().URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask).first!
        lastEditedFilename = NSString.pathWithComponents([appSupportFolder.path!, "WatchThis", "LastEdited"])

        let picturesFolder = NSFileManager.defaultManager().URLsForDirectory(.PicturesDirectory, inDomains: .UserDomainMask).first!
        slideshowFolder = NSString.pathWithComponents([picturesFolder.path!, "WatchThis Slideshows"])
    }

    static var slideshowFolder: String
    {
        get { return stringForKey(SlideshowFolderKey) }
        set { super.setValue(newValue, key: SlideshowFolderKey) }
    }

    static var lastEditedFilename: String
    {
        get { return stringForKey(LastEditedFilenameKey) }
        set { super.setValue(newValue, key: LastEditedFilenameKey) }
    }
}