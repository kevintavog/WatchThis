//
//

import Async
import RangicCore

protocol SlideshowDriverDelegate
{
    func show(mediaData: MediaData)
    func stateChanged(currentState: SlideshowDriver.DriverState)
    func pauseVideo()
    func resumeVideo()
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
    let mediaList: MediaList

    var timer:NSTimer? = nil

    var driverState = DriverState.Created { didSet { delegate.stateChanged(driverState) } }


    init(list: MediaList, data: SlideshowData, delegate: SlideshowDriverDelegate)
    {
        self.delegate = delegate
        slideshowData = data
        mediaList = list

        super.init()

        mediaList.beginEnumerate() {
            self.play()
        }
    }

    func play()
    {
        Logger.info("SlideshowDriver.play \(driverState)")
        if driverState == .Playing {
            return
        }

        if driverState == .Paused && mediaList.mostRecent(self)?.type == SupportedMediaTypes.MediaType.Video {
            driverState = .Playing
            delegate.resumeVideo()
            return
        }

        driverState = .Playing
        setupTimer(slideshowData.slideSeconds)
        next()
    }

    func pause()
    {
        Logger.info("SlideshowDriver.pause \(driverState)")
        if driverState != .Paused {
            driverState = .Paused
            destroyTimer()

            if mediaList.mostRecent(self)?.type == SupportedMediaTypes.MediaType.Video {
                delegate.pauseVideo()
            }
        }
    }

    func resume()
    {
        Logger.info("SlideshowDriver.resume \(driverState)")
        if driverState == .Paused {
            play()
        }
    }

    func pauseOrResume()
    {
        Logger.info("SlideshowDriver.pauseOrResume \(driverState)")
        if driverState == .Paused {
            resume()
        }
        else if driverState == .Playing {
            pause()
        }
    }

    func stop()
    {
        Logger.info("SlideshowDriver.stop \(driverState)")
        driverState = .Stopped
        destroyTimer()
    }

    func next()
    {
        Logger.info("SlideshowDriver.next \(driverState)")
        nextSlide()
    }

    func nextSlide()
    {
        if let file = mediaList.next(self) {
            showFile(file)
        } else {
            Logger.info("SlideshowDriver, hit end of list")
            mediaList.beginEnumerate() {
                self.nextSlide()
            }
        }
    }

    func previous()
    {
        Logger.info("SlideshowDriver.previous \(driverState)")

        if let file = mediaList.previous(self) {
            showFile(file)
        } else {
            setupTimer(slideshowData.slideSeconds)
        }
    }

    func showFile(mediaData: MediaData)
    {
        if !mediaData.doesExist() {
            Logger.warn("File no longer exists: \(mediaData.url.path!)")
            Async.main {
                self.nextSlide()
            }
            return
        }
        delegate.show(mediaData)
        if mediaData.type != SupportedMediaTypes.MediaType.Video {
            if driverState == .Playing {
                setupTimer(slideshowData.slideSeconds)
            }
        } else {
            destroyTimer()
        }
    }

    // MARK: Updates from client
    func videoDidEnd()
    {
        Logger.info("SlideshowDriver.videoDidEnd")
        nextSlide()
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
}