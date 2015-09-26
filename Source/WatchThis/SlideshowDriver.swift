//
//

import Async
import RangicCore

protocol SlideshowDriverDelegate
{
    func show(mediaData: MediaData) -> Double?
    func stateChanged(currentState: SlideshowDriver.DriverState)
}

class SlideshowDriver : NSObject
{
    enum DriverState:Int
    {
        case Created,
                Playing,
                Paused,
                Stopped
    }

    var delegate: SlideshowDriverDelegate
    let slideshowData: SlideshowData
    var mediaFiles:[MediaData] = []
    var totalCount = 0

    var previousFiles = [MediaData]()
    var previousIndex: Int? = nil
    var timer:NSTimer? = nil

    var driverState = DriverState.Created { didSet { delegate.stateChanged(driverState) } }


    init(data: SlideshowData, delegate: SlideshowDriverDelegate)
    {
        self.delegate = delegate
        slideshowData = data

        super.init()

        beginEnumerate()
    }

    var currentIndex: Int {
        get {
            var index = totalCount - mediaFiles.count
            if previousIndex != nil {
                index -= previousFiles.count - previousIndex! - 1
            }
            return index
        }
    }

    func play()
    {
        Logger.log("SlideshowDriver.play \(driverState)")
        if driverState == .Playing {
            return
        }
        driverState = .Playing
        setupTimer(slideshowData.slideSeconds)
        next()
    }

    func pauseOrResume()
    {
        Logger.log("SlideshowDriver.pauseOrResume \(driverState)")
        if driverState == .Paused {
            play()
        }
        else if driverState == .Playing {
            driverState = .Paused
            destroyTimer()
        }
    }

    func stop()
    {
        Logger.log("stop \(driverState)")
        driverState = .Stopped
        destroyTimer()
    }

    func next()
    {
        Logger.log("SlideshowDriver.next \(driverState)")
        nextSlide()
    }

    func nextSlide()
    {
        // If we're looking at previous files, go to the next one in that list. Until we catch up to the
        // last file we displayed
        var file: MediaData?
        if previousIndex != nil {
            ++(previousIndex!)
            if previousIndex < previousFiles.count {
                file = previousFiles[previousIndex!]
            } else {
                previousIndex = nil
            }
        }

        if file == nil {
            if mediaFiles.count == 0 {
                beginEnumerate()
                return
            }

            let index = arc4random_uniform(UInt32(mediaFiles.count))
            file = mediaFiles.removeAtIndex(Int(index))

            previousFiles.append(file!)
            while previousFiles.count > 1000 {
                previousFiles.removeAtIndex(0)
            }
        }

        showFile(file!)
    }

    func previous()
    {
        Logger.log("SlideshowDriver.previous \(driverState)")

        var index = 0
        if previousIndex == nil {
            // The last item (-1) is currently being displayed. -2 is the previous item
            index = previousFiles.count - 2
        } else {
            index = previousIndex! - 1
        }

        if index < 0 {
            setupTimer(slideshowData.slideSeconds)
            return
        }

        previousIndex = index
        showFile(previousFiles[previousIndex!])
    }

    func showFile(mediaData: MediaData)
    {
        if var overrideDurationSeconds = delegate.show(mediaData) {
            if overrideDurationSeconds == 0 {
                overrideDurationSeconds = slideshowData.slideSeconds
            }
            setupTimer(overrideDurationSeconds)
        }
        else {
            // Delegate doesn't want to show file - get the next one
            Logger.log("Skipping file - \(mediaData.url!.path)")
            nextSlide()
        }
    }

    // MARK: Timer management
    private func setupTimer(durationSeconds: Double)
    {
        if timer != nil {
            timer?.invalidate()
        }

        timer = NSTimer.scheduledTimerWithTimeInterval(durationSeconds, target: self, selector: "timerFired:", userInfo: nil, repeats: true)
    }

    private func destroyTimer()
    {
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }

    func timerFired(someTimer: NSTimer)
    {
        Async.main {
            self.nextSlide()
        }
    }

    // MARK: Enumerate folders/files
    private func beginEnumerate()
    {
        Async.background {
            self.totalCount = 0
            for folder in self.slideshowData.folderList {
                self.addFolder(folder)
            }

            Logger.log("Found \(self.mediaFiles.count) files")
            CoreNotifications.postNotification(Notifications.SlideshowMedia.AllFilesAvailable, object: self)

            Async.main {
                self.play()
            }
        }
    }

    private func addFolder(folderName:String)
    {
        let startedEmpty = mediaFiles.count == 0
        var folders = [String]()
        if NSFileManager.defaultManager().fileExistsAtPath(folderName) {
            if let files = getFiles(folderName) {
                for f in files {
                    let mediaType = SupportedMediaTypes.getTypeFromFileExtension(((f.path!) as NSString).pathExtension)
                    if mediaType == SupportedMediaTypes.MediaType.Image || mediaType == SupportedMediaTypes.MediaType.Video {
                        mediaFiles.append(FileMediaData.create(f, mediaType: mediaType))
                        ++totalCount
                    }

                    var isFolder: ObjCBool = false
                    if NSFileManager.defaultManager().fileExistsAtPath(f.path!, isDirectory:&isFolder) && isFolder {
                        folders.append(f.path!)
                    }
                }
            }
        }

        if startedEmpty && mediaFiles.count > 0 {
            // first files available
            CoreNotifications.postNotification(Notifications.SlideshowMedia.FirstFilesAvailable, object: self)
        }

        for folder in folders {
            addFolder(folder)
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