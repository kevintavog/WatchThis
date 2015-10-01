//
//  WatchThis
//

import RangicCore
import Async

/// Responsible for enumerating folders to collect files, as well as providing the files for displaying
class MediaList
{
    private let BytesForSignature = 8 * 1024

    private let slideshowData: SlideshowData
    private var mediaList:[MediaData] = []
    internal private(set) var totalCount = 0
    private let mutex = Mutex()
    private var visitedFiles = [String:String]()

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
            self.visitedFiles = [String:String]()
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
                        if let signature = getSignature(f.path!) {
                            if visitedFiles.keys.contains(signature) {
                                Logger.log("Ignoring duplicate: \(visitedFiles[signature]!) == \(f.path!)")
                            } else {
                                visitedFiles[signature] = f.path!
                                mediaList.append(FileMediaData.create(f, mediaType: mediaType))
                                ++totalCount
                            }
                        } else {
                            Logger.log("Unable to create signature for '\(f.path!)'")
                        }
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

    private func getFiles(folderName: String) -> [NSURL]?
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

    private func getSignature(filename: String) -> String?
    {
        do {
            let attrs: NSDictionary? = try NSFileManager.defaultManager().attributesOfItemAtPath(filename)
            let length = attrs!.fileSize()
            if let fileHandle = NSFileHandle(forReadingAtPath: filename) {
                let data = fileHandle.readDataOfLength(BytesForSignature)
                var digest = [UInt8](count:Int(CC_SHA1_DIGEST_LENGTH), repeatedValue: 0)
                CC_SHA1(data.bytes, CC_LONG(data.length), &digest)

                let output = NSMutableString(capacity: Int(9 + CC_SHA1_DIGEST_LENGTH))
                output.appendFormat("%08X-", length)
                for byte in digest {
                    output.appendFormat("%02x", byte)
                }
                return output as String            }
        } catch {
            return nil
        }

        return nil
    }
}
