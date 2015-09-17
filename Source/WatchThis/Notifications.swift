//
//

import Foundation

import RangicCore

class Notifications : CoreNotifications
{
    class SlideshowListProvider
    {
        static let EnumerationCompleted = "SlideshowListProvider.EnumerationCompleted"
    }

    class SlideshowMedia
    {
        static let FirstFilesAvailable = "SlideshowMedia.FirstFilesAvailable"
        static let AllFilesAvailable = "SlideshowMedia.AllFilesAvailable"
    }
}