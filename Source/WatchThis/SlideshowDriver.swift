//
//

import Async
import RangicCore

protocol SlideshowDriverDelegate
{
    func show(mediaData: MediaData)
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
    var driverState = DriverState.Created
    let slideshowData: SlideshowData
    var mediaFiles:[MediaData] = []
    var recentFiles = [MediaData]()
    var timer:NSTimer? = nil
    var currentState: DriverState = .Created {
        didSet {
Logger.log("didSet")
            delegate.stateChanged(currentState)
        }
    }


    init(data: SlideshowData, delegate: SlideshowDriverDelegate)
    {
        self.delegate = delegate
        slideshowData = data

        super.init()

        beginEnumerate()
    }

    func play()
    {
        Logger.log("SlideshowDriver.play \(currentState)")
        if driverState == .Playing {
            return
        }
        driverState = .Playing
        setupTimer()
        next()
    }

    func pauseOrResume()
    {
        Logger.log("SlideshowDriver.pauseOrResume \(currentState)")
        if currentState == .Paused {
            play()
        }
        else if currentState == .Playing {
            currentState = .Paused
            destroyTimer()
        }
    }

    func stop()
    {
    }

    func next()
    {
        if mediaFiles.count == 0 {
            beginEnumerate()
            return
        }

        let index = arc4random_uniform(UInt32(mediaFiles.count))
        let file = mediaFiles.removeAtIndex(Int(index))

        recentFiles.append(file)
        while recentFiles.count > 1000 {
            recentFiles.removeAtIndex(0)
        }

        delegate.show(file)
    }

    func previous()
    {
    }

    // MARK: Timer management
    private func setupTimer()
    {
        if timer != nil {
            timer?.invalidate()
        }

        timer = NSTimer.scheduledTimerWithTimeInterval(1.0 /* timerValue() */, target: self, selector: "timerFired:", userInfo: nil, repeats: true)
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
            self.next()
        }
    }

    private func timerValue() -> Double
    {
        let time = slideshowData.slideSeconds * 1000
        if time < 100 {
            return 100
        }
        return time
    }

    // MARK: Enumerate folders/files
    private func beginEnumerate()
    {
        Async.background {
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