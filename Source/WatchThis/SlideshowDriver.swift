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
    func showAlert(_ message: String)
    var numberOfViews: UInt { get }
}

class SlideshowDriver : NSObject, MediaListDelegate
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
    let lookupMutex = PThreadMutex()

    var timer:Timer? = nil

    var driverState = DriverState.created { didSet { delegate.stateChanged(driverState) } }


    init(list: MediaList, data: SlideshowData, delegate: SlideshowDriverDelegate)
    {
        self.delegate = delegate
        slideshowData = data
        mediaList = list

        super.init()

        mediaList.setDelegate(delegate: self)
        mediaList.beginEnumerate() {
            self.startInitialViews()
        }
    }

    func startInitialViews() {
        Logger.info("SlideshowDriver.startInitialViews")
        driverState = .playing
        setupTimer()
        for _ in 1...delegate.numberOfViews {
            nextSlide()
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
        setupTimer()
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
        lookupMutex.sync {
            mediaList.next(self, completion: { (mediaData: MediaData?) -> () in
                if mediaData == nil {
                    Logger.error("mediaList.next returned a nil MediaData")
                    Async.main {
                        self.nextSlide()
                    }
                } else {
                    self.showFile(mediaData!)
                }
            })
        }
    }

    func previous()
    {
        Logger.info("SlideshowDriver.previous \(driverState)")

        if let file = mediaList.previous(self) {
            showFile(file)
        } else {
            setupTimer()
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
        Async.main {
            self.delegate.show(mediaData)
            if mediaData.type != SupportedMediaTypes.MediaType.video {
                if self.driverState == .playing {
                    self.setupTimer()
                }
            } else {
                self.destroyTimer()
            }
        }
    }

    // MARK: Updates from client
    func videoDidEnd()
    {
        Logger.info("SlideshowDriver.videoDidEnd")
        nextSlide()
    }

    fileprivate func getSlideDuration() -> Double {
        if slideshowData.slideSeconds == slideshowData.slideSecondsMax {
            return slideshowData.slideSeconds
        }

        return slideshowData.slideSeconds + Double(arc4random_uniform(UInt32(slideshowData.slideSecondsMax - slideshowData.slideSeconds) + 1))
    }

    // MARK: Timer management
    fileprivate func setupTimer()
    {
        if timer != nil {
            timer?.invalidate()
        }

        timer = Timer.scheduledTimer(timeInterval: getSlideDuration(), target: self, selector: #selector(SlideshowDriver.timerFired(_:)), userInfo: nil, repeats: true)
    }

    fileprivate func destroyTimer()
    {
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }

    @objc func timerFired(_ someTimer: Timer)
    {
        Async.main {
            self.nextSlide()
        }
    }

    func mediaListError(_ message: String)
    {
        Async.main {
            Logger.info("mediaListError: \(message)")
            self.delegate.showAlert(message)
        }
    }

}
