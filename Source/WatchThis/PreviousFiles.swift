//
//  WatchThis
//

import RangicCore

class PreviousList
{
    static fileprivate let maxEntries = 100

    fileprivate var previousFiles = [PreviousEntry]()
    fileprivate var previousIndex: Int? = nil

    func mostRecent() -> MediaData?
    {
        if previousFiles.count > 0 {
            return previousFiles.last?.mediaData
        }
        return nil
    }

    func next() -> MediaData?
    {
        if previousIndex != nil {
            (previousIndex!) += 1
            let index = previousIndex!
            if index < previousFiles.count {
                return previousFiles[index].mediaData
            } else {
                previousIndex = nil
            }
        }
        return nil
    }

    func previous() -> MediaData?
    {
        var index = 0
        if previousIndex == nil {
            // The last item (-1) is currently being displayed. -2 is the previous item
            index = previousFiles.count - 2
        } else {
            index = previousIndex! - 1
        }

        if index < 0 {
            return nil
        }

        previousIndex = index
        return previousFiles[index].mediaData
    }

    func add(_ mediaData: MediaData, index: Int)
    {
        previousFiles.append(PreviousEntry(mediaData: mediaData, index: index))
        while previousFiles.count > PreviousList.maxEntries {
            previousFiles.remove(at: 0)
        }
    }

    func currentIndex() -> Int
    {
        return previousFiles[previousIndex!].index
    }

    func hasIndex() -> Bool
    {
        return previousIndex != nil
    }
}

struct PreviousEntry
{
    let mediaData: MediaData
    let index: Int

    init(mediaData: MediaData, index: Int)
    {
        self.mediaData = mediaData
        self.index = index
    }
}
