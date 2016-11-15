//
//  WatchThis
//

import RangicCore
import Async

/// Responsible for enumerating folders to collect files, as well as providing the files for displaying
class MediaList
{
    fileprivate let BytesForSignature = 2 * 1024

    fileprivate let slideshowData: SlideshowData
    fileprivate var mediaList:[MediaData] = []
    internal fileprivate(set) var totalCount = 0
    fileprivate let mutex = Mutex()
    fileprivate var visitedFiles = [String:String]()

    var previousList = [SlideshowDriver:PreviousList]()


    init(data: SlideshowData)
    {
        slideshowData = data
    }

    func next(_ driver: SlideshowDriver) -> MediaData?
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
            file = mediaList.remove(at: Int(index))

            list.add(file!, index: totalCount - mediaList.count)
        }

        return file
    }

    func currentIndex(_ driver: SlideshowDriver) -> Int
    {
        let list = getDriverList(driver)
        if list.hasIndex() {
            return list.currentIndex()
        } else {
            return totalCount - mediaList.count
        }
    }


    func previous(_ driver: SlideshowDriver) -> MediaData?
    {
        return getDriverList(driver).previous()
    }

    func mostRecent(_ driver: SlideshowDriver) -> MediaData?
    {
        return getDriverList(driver).mostRecent()
    }

    fileprivate func getDriverList(_ driver: SlideshowDriver) -> PreviousList
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
    internal func beginEnumerate(_ onAvailable: @escaping () -> ())
    {
        Async.background {
            self.visitedFiles = [String:String]()
            self.totalCount = 0
            for folder in self.slideshowData.folderList {
                self.addFolder(folder, onAvailable: onAvailable)
            }

            Logger.info("SlideshowDriver: Found \(self.mediaList.count) files")
        }
    }

    fileprivate func addFolder(_ folderName: String, onAvailable: @escaping () -> ())
    {
        let startedEmpty = mediaList.count == 0
        var folders = [String]()
        if FileManager.default.fileExists(atPath: folderName) {
            if let files = getFiles(folderName) {
                for f in files {
                    let mediaType = SupportedMediaTypes.getTypeFromFileExtension(((f.path!) as NSString).pathExtension)
                    if mediaType == SupportedMediaTypes.MediaType.image || mediaType == SupportedMediaTypes.MediaType.video {
                        if let signature = getSignature(f.path!) {
                            if visitedFiles.keys.contains(signature) {
                                Logger.info("Ignoring duplicate: \(visitedFiles[signature]!) == \(f.path!)")
                            } else {
                                visitedFiles[signature] = f.path!
                                mediaList.append(FileMediaData.create(f as URL, mediaType: mediaType))
                                totalCount += 1
                            }
                        } else {
                            Logger.warn("Unable to create signature for '\(f.path!)'")
                        }
                    }

                    var isFolder: ObjCBool = false
                    if FileManager.default.fileExists(atPath: f.path!, isDirectory:&isFolder) && isFolder.boolValue {
                        folders.append(f.path!)
                    }
                }
            }
        }

        if startedEmpty && mediaList.count > 0 {
            Logger.info("First files available: \(mediaList.count)")
            Async.main {
                onAvailable()
            }
        }

        for folder in folders {
            addFolder(folder, onAvailable: onAvailable)
        }
    }

    fileprivate func getFiles(_ folderName: String) -> [NSURL]?
    {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: NSURL(fileURLWithPath: folderName) as URL,
                includingPropertiesForKeys: nil,
                options:FileManager.DirectoryEnumerationOptions.skipsHiddenFiles) as [NSURL]?
        }
        catch let error {
            Logger.error("Failed getting files in \(folderName): \(error)")
            return nil
        }
    }

    fileprivate func getSignature(_ filename: String) -> String?
    {
        do {
            let attrs: NSDictionary? = try FileManager.default.attributesOfItem(atPath: filename) as NSDictionary?
            let length = attrs!.fileSize()
            if let fileHandle = FileHandle(forReadingAtPath: filename) {
                let startOfFile = fileHandle.readData(ofLength: BytesForSignature)
                fileHandle.seek(toFileOffset: length - UInt64(BytesForSignature))
                let endOfFile = fileHandle.readData(ofLength: BytesForSignature)

                let data = NSMutableData(data: startOfFile)
                data.append(endOfFile)

                var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
                CC_SHA1(data.bytes, CC_LONG(data.length), &digest)

                let output = NSMutableString(capacity: Int(9 + CC_SHA1_DIGEST_LENGTH))
                output.appendFormat("%08X-", length)
                for byte in digest {
                    output.appendFormat("%02x", byte)
                }
                return output as String            }
        } catch let error {
            Logger.error("Failed getting signature for \(filename): \(error)")
            return nil
        }

        return nil
    }
}
