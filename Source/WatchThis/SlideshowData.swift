//
//

import RangicCore

class SlideshowData
{
    enum FileError : ErrorType
    {
        case FilenameNotSet,
                NameNotSet,
                NoFolders,
                SaveFailed(Int, String),
                LoadFailed(Int, String),
                InvalidSlideshowFile(filename: String, message: String)
    }

    static let FileExtension = "watchthisslideshow"

    var filename:String?
    var name:String?
    var slideSeconds:Double = 10.0
    var folderList = [String]()


    init()
    {
        reset()
    }

    static func load(fromFile: String) throws -> SlideshowData
    {
        do {
            let fileText = try String(contentsOfFile: fromFile, encoding: NSUTF8StringEncoding)

            let json = JSON(data: fileText.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
            guard json["name"].string != nil else { throw FileError.InvalidSlideshowFile(filename: fromFile, message: "Missing name") }

            let slideshowData = SlideshowData()
            slideshowData.name = json["name"].stringValue
            slideshowData.slideSeconds = json["slideSeconds"].doubleValue

            for folderJson in json["folders"].arrayValue {
                slideshowData.folderList.append(folderJson["path"].stringValue)
            }

            return slideshowData
        } catch let f as FileError {
            throw f
        } catch let e as NSError {
            Logger.log("Load failed: \(e.code): \(e.localizedDescription)")
            throw FileError.LoadFailed(e.code, e.localizedDescription)
        }
    }

    func save() throws
    {
        guard filename != nil else { throw FileError.FilenameNotSet }
        guard name != nil else { throw FileError.NameNotSet }
        guard folderList.count > 0 else { throw FileError.NoFolders }

        // Form up json
        var json = JSON([String: AnyObject]())
        json["name"].string = name!
        json["slideSeconds"].double = slideSeconds

        var jsonFolderList = [AnyObject]()

        for folder in folderList {
            var jsonFolder = [String: AnyObject]()
            jsonFolder["path"] = folder
            jsonFolderList.append(jsonFolder)
        }
        json["folders"].object = jsonFolderList

        do {

            if !NSFileManager.defaultManager().fileExistsAtPath(Preferences.slideshowFolder) {
                Logger.log("Creating slideshow folder: \(Preferences.slideshowFolder)")
                try NSFileManager.defaultManager().createDirectoryAtPath(Preferences.slideshowFolder, withIntermediateDirectories: false, attributes: nil)
            }

            try json.rawString()!.writeToFile(filename!, atomically: false, encoding: NSUTF8StringEncoding)
        } catch let e as NSError {
            Logger.log("Save failed: \(e.code): \(e.localizedDescription)")
            throw FileError.SaveFailed(e.code, e.localizedDescription)
        }
    }

    func reset()
    {
        filename = nil
        name = nil
        slideSeconds = 10.0
        folderList = []
    }

    static func getFilenameForName(name: String) -> String
    {
        return ((Preferences.slideshowFolder as NSString).stringByAppendingPathComponent(name) as NSString).stringByAppendingPathExtension(FileExtension)!
    }
}
