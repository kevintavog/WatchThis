//
//  WatchThis
//

import RangicCore
import Async

protocol MediaListDelegate
{
    func mediaListError(_ message: String)
}

/// Responsible for enumerating folders to collect files, as well as providing the media for displaying
class MediaList
{
    fileprivate var delegate: MediaListDelegate?
    fileprivate let slideshowData: SlideshowData
    fileprivate var mediaList:[MediaData] = []
    internal fileprivate(set) var totalCount = 0
    fileprivate var visitedFiles = [String:String]()

    fileprivate var searchResults: FindAPhotoResults?
    fileprivate var searchItems: [MediaData] = []           // The remaining search items - items are removed randomly

    fileprivate var previousList = [SlideshowDriver:PreviousList]()


    init(data: SlideshowData)
    {
        slideshowData = data
    }

    func setDelegate(delegate: MediaListDelegate)
    {
        self.delegate = delegate
    }
    
    func next(_ driver: SlideshowDriver, completion: @escaping (_ mediaData: MediaData?) -> ())
    {
        let list = getDriverList(driver)
        
        // If we're looking at previous items, go to the next one in that list. Until we catch up to the
        // last item we displayed
        if let item = list.next() {
            completion(item)
            return
        }

        if (isFolderBased() && mediaList.count == 0) || (isSearchBased() && searchItems.count == 0) {
            beginEnumerate {
                self.nextRandom(driver, completion: completion)
                return
            }
        } else {
            nextRandom(driver, completion: completion)
        }
    }

    fileprivate func nextRandom(_ driver: SlideshowDriver, completion: @escaping(_ mediaData: MediaData?) -> ())
    {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let list = getDriverList(driver)

        if isFolderBased() && mediaList.count > 0 {
            let index = Int(arc4random_uniform(UInt32(mediaList.count)))
            let item = mediaList.remove(at: index)
            list.add(item, index: totalCount - mediaList.count)
            completion(item)
            return
        } else if isSearchBased() && searchItems.count > 0 {
            let index = Int(arc4random_uniform(UInt32(searchItems.count)))
            objc_sync_enter(self)
            let mediaData = searchItems[index]
            list.add(mediaData, index: index)
            searchItems.remove(at: index)
            objc_sync_exit(self)

            completion(mediaData)
            return
        } else {
            Logger.error("Unsupported slideshow (nextRandom)")
        }

        completion(nil)
    }

    func currentIndex(_ driver: SlideshowDriver) -> Int
    {
        let list = getDriverList(driver)
        if list.hasIndex() {
            return list.currentIndex()
        } else {
            if isFolderBased() {
                return totalCount - mediaList.count
            } else if isSearchBased() {
                return totalCount - searchItems.count
            } else {
                Logger.error("Unsupported slideshow (currentIndex)")
                return 0
            }
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


    internal func isFolderBased() -> Bool
    {
        return self.slideshowData.folderList.count > 0
    }

    internal func isSearchBased() -> Bool
    {
        return self.slideshowData.searchQuery != nil
    }

    internal func beginEnumerate(_ onAvailable: @escaping () -> ())
    {
        Async.background {
            self.visitedFiles = [String:String]()
            self.totalCount = 0

            if self.isFolderBased() {
                self.enumerateFolders(onAvailable)
            } else if self.isSearchBased() {
                self.enumerateSearch(onAvailable)
            } else {
                Logger.warn("Unsupported slideshow type (neither file nor search based)")
            }
        }
    }

    // MARK: Handle FindAPhoto search
    fileprivate func enumerateSearch(_ onAvailable: @escaping () ->()) {
        searchItems = [MediaData]()
        var offset = 1
        self.totalCount = 0
        var notifyAvailable = true
        repeat {
            if let ids = synchronousSearch(offset: offset) {
                offset += ids.count
                objc_sync_enter(self)
                self.searchItems.append(contentsOf: ids)
                objc_sync_exit(self)
            } else {
                return
            }

            if notifyAvailable {
                notifyAvailable = false
                Async.main {
                    onAvailable()
                }
            }
        } while (offset < self.totalCount)
    }

    fileprivate func synchronousSearch(offset: Int) -> [MediaData]? {
        let responseCompleted = DispatchSemaphore(value: 0)

        var failed = false
        var md = [MediaData]()

        FindAPhotoResults.search(Preferences.findAPhotoHost, text: self.slideshowData.searchQuery!, first: offset, count: 100, completion: { (results: FindAPhotoResults) -> () in
            self.searchResults = results
            if results.hasError {
                self.delegate?.mediaListError(results.errorMessage!)
                failed = true
            } else {
                self.totalCount = results.totalMatches!
                md = results.items
            }
            responseCompleted.signal()
        })


        responseCompleted.wait()
        return failed ? nil : md
    }
    
    // MARK: Enumerate folders/files
    fileprivate func enumerateFolders(_ onAvailable: @escaping () ->())
    {
        for folder in self.slideshowData.folderList {
            self.addFolder(folder, onAvailable: onAvailable)
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
                        let mediaType = FileMediaData.create(f as URL, mediaType: mediaType)
                        if visitedFiles.keys.contains(mediaType.mediaSignature) {
                            Logger.info("Ignoring duplicate: \(visitedFiles[mediaType.mediaSignature]!) == \(f.path!)")
                        } else {
                            visitedFiles[mediaType.mediaSignature] = f.path!
                            mediaList.append(mediaType)
                            totalCount += 1
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
}
