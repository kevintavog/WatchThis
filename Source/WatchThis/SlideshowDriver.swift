//
//

import Async
import RangicCore

protocol SlideshowDriverDelegate
{
    func show(_ mediaData: MediaData)
    func stateChanged(_ currentState: SlideshowDriver.DriverState)
    func pauseVideo()
    func resumeVideo()
}

class SlideshowDriver : NSObject
{
    enum DriverState:Int
    {
        case created,
                playing,
                paused,
                stopped
    }

    var delegate: SlideshowDriverDelegate
    let slideshowData: SlideshowData
    let mediaList: MediaList

    var timer:Timer? = nil

    var driverState = DriverState.created { didSet { delegate.stateChanged(driverState) } }


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
        if driverState == .playing {
            return
        }

        if driverState == .paused && mediaList.mostRecent(self)?.type == SupportedMediaTypes.MediaType.video {
            driverState = .playing
            delegate.resumeVideo()
            return
        }

        driverState = .playing
        setupTimer(slideshowData.slideSeconds)
        next()
    }

    func pause()
    {
        Logger.info("SlideshowDriver.pause \(driverState)")
        if driverState != .paused {
            driverState = .paused
            destroyTimer()

            if mediaList.mostRecent(self)?.type == SupportedMediaTypes.MediaType.video {
                delegate.pauseVideo()
            }
        }
    }

    func resume()
    {
        Logger.info("SlideshowDriver.resume \(driverState)")
        if driverState == .paused {
            play()
        }
    }

    func pauseOrResume()
    {
        Logger.info("SlideshowDriver.pauseOrResume \(driverState)")
        if driverState == .paused {
            resume()
        }
        else if driverState == .playing {
            pause()
        }
    }

    func stop()
    {
        Logger.info("SlideshowDriver.stop \(driverState)")
        driverState = .stopped
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

    func showFile(_ mediaData: MediaData)
    {
        if !mediaData.doesExist() {
            Logger.warn("File no longer exists: \(mediaData.url.path)")
            Async.main {
                self.nextSlide()
            }
            return
        }
        delegate.show(mediaData)
        if mediaData.type != SupportedMediaTypes.MediaType.video {
            if driverState == .playing {
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
    fileprivate func setupTimer(_ durationSeconds: Double)
    {
        if timer != nil {
            timer?.invalidate()
        }

        timer = Timer.scheduledTimer(timeInterval: durationSeconds, target: self, selector: #selector(SlideshowDriver.timerFired(_:)), userInfo: nil, repeats: true)
    }

    fileprivate func destroyTimer()
    {
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }

    func timerFired(_ someTimer: Timer)
    {
        Async.main {
            self.nextSlide()
        }
    }
}
