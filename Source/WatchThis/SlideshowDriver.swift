//
//

import Async

class SlideshowDriver
{
    let slideshowData: SlideshowData
    private init(data: SlideshowData)
    {
        slideshowData = data
    }

    static func from(data: SlideshowData) -> SlideshowDriver
    {
        let driver = SlideshowDriver(data: data)
        driver.beginEnumerate()
        return driver
    }

    func play()
    {
    }

    func pauseOrResume()
    {
    }

    func stop()
    {
    }

    func next()
    {
    }

    func previous()
    {
    }

    func beginEnumerate()
    {
        Async.background {

        }
    }
}