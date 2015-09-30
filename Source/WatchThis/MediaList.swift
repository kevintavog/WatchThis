//
//  WatchThis
//

import RangicCore
import Async

/// Responsible for enumerating folders to collect files, as well as providing the files for displaying
class MediaList
{
    private let slideshowData: SlideshowData
    private var mediaList:[MediaData] = []
    internal private(set) var totalCount = 0
    private let mutex = Mutex()

    var previousList = [SlideshowDriver:PreviousList]()

    init(data: SlideshowData)
    {
        slideshowData = data
    }

    func next(driver: SlideshowDriver) -> MediaData?
    {
        let list = getDriverList(driver)

        // If we're looking at previous files, go to the next one in that list. Until we catch up to the
        // last file we displayed
        var file = list.next()
        if file == nil {
            if mediaList.count == 0 {
                return nil
            }

            objc_sync_enter(self)
            defer { objc_sync_exit(self) }

            let index = arc4random_uniform(UInt32(mediaList.count))
            file = mediaList.removeAtIndex(Int(index))

            list.add(file!, index: totalCount - mediaList.count)
        }

        return file
    }

    func currentIndex(driver: SlideshowDriver) -> Int
    {
        let list = getDriverList(driver)
        if list.hasIndex() {
            return list.currentIndex()
        } else {
            return totalCount - mediaList.count
        }
    }


    func previous(driver: SlideshowDriver) -> MediaData?
    {
        return getDriverList(driver).previous()
    }

    func mostRecent(driver: SlideshowDriver) -> MediaData?
    {
        return getDriverList(driver).mostRecent()
    }

    private func getDriverList(driver: SlideshowDriver) -> PreviousList
    {
        var list: PreviousList
        if previousList[driver] == nil {
            list = PreviousList()
            previousList[driver] = list
        } else {
            list = previousList[driver]!
        }

        return list
    }



    // MARK: Enumerate folders/files
    internal func beginEnumerate(onAvailable: () -> ())
    {
        Async.background {
            self.totalCount = 0
            for folder in self.slideshowData.folderList {
                self.addFolder(folder, onAvailable: onAvailable)
            }

            Logger.log("SlideshowDriver: Found \(self.mediaList.count) files")
        }
    }

    private func addFolder(folderName: String, onAvailable: () -> ())
    {
        let startedEmpty = mediaList.count == 0
        var folders = [String]()
        if NSFileManager.defaultManager().fileExistsAtPath(folderName) {
            if let files = getFiles(folderName) {
                for f in files {
                    let mediaType = SupportedMediaTypes.getTypeFromFileExtension(((f.path!) as NSString).pathExtension)
                    if mediaType == SupportedMediaTypes.MediaType.Image || mediaType == SupportedMediaTypes.MediaType.Video {
                        mediaList.append(FileMediaData.create(f, mediaType: mediaType))
                        ++totalCount
                    }

                    var isFolder: ObjCBool = false
                    if NSFileManager.defaultManager().fileExistsAtPath(f.path!, isDirectory:&isFolder) && isFolder {
                        folders.append(f.path!)
                    }
                }
            }
        }

        if startedEmpty && mediaList.count > 0 {
            Logger.log("First files available: \(mediaList.count)")
            Async.main {
                onAvailable()
            }
        }

        for folder in folders {
            addFolder(folder, onAvailable: onAvailable)
        }
    }

    private func getFiles(folderName:String) -> [NSURL]?
    {
        do {
            return try NSFileManager.defaultManager().contentsOfDirectoryAtURL(
                NSURL(fileURLWithPath: folderName),
                includingPropertiesForKeys: nil,
                options:NSDirectoryEnumerationOptions.SkipsHiddenFiles)
        }
        catch {
            return nil
        }
    }
}
