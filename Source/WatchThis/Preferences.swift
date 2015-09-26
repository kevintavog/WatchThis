//
//

import Foundation
import RangicCore

class Preferences : BasePreferences
{
    static let SlideshowFileExtension = "watchthisslideshow"
    static private let SlideshowFolderKey = "SlideshowFolder"
    static private let LastEditedFilenameKey = "LastEditedFilename"
    static private let VideoPlayerVolumeKey = "VideoPlayerVolume"
    static private let BaseLocationLookupKey = "BaseLocationLookup"

    static func setMissingDefaults()
    {
        let appSupportFolder = NSFileManager.defaultManager().URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask).first!
        lastEditedFilename = NSString.pathWithComponents([appSupportFolder.path!, "WatchThis", "LastEdited"])
        lastEditedFilename = (lastEditedFilename as NSString).stringByAppendingPathExtension(SlideshowFileExtension)!

        let picturesFolder = NSFileManager.defaultManager().URLsForDirectory(.PicturesDirectory, inDomains: .UserDomainMask).first!
        slideshowFolder = NSString.pathWithComponents([picturesFolder.path!, "WatchThis Slideshows"])

        setDefaultValue("http://open.mapquestapi.com", key: BaseLocationLookupKey)
    }

    static var baseLocationLookup: String
    {
        get { return stringForKey(BaseLocationLookupKey) }
        set { super.setValue(newValue, key: BaseLocationLookupKey) }
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

    static var videoPlayerVolume: Float
    {
        get { return floatForKey(VideoPlayerVolumeKey) }
        set { setValue(newValue, key: VideoPlayerVolumeKey) }
    }
}