//
//

import Foundation
import RangicCore

class Preferences : BasePreferences
{
    static let SlideshowFileExtension = "watchthisslideshow"
    static fileprivate let SlideshowFolderKey = "SlideshowFolder"
    static fileprivate let LastEditedFilenameKey = "LastEditedFilename"
    static fileprivate let VideoPlayerVolumeKey = "VideoPlayerVolume"
    static fileprivate let BaseLocationLookupKey = "BaseLocationLookup"

    static func setMissingDefaults()
    {
        let appSupportFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        lastEditedFilename = NSString.path(withComponents: [appSupportFolder.path, "WatchThis", "LastEdited"])
        lastEditedFilename = (lastEditedFilename as NSString).appendingPathExtension(SlideshowFileExtension)!

        let picturesFolder = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        slideshowFolder = NSString.path(withComponents: [picturesFolder.path, "WatchThis Slideshows"])

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
