//
//

import RangicCore
import SwiftyJSON

class SlideshowData
{
    enum FileError : Error
    {
        case filenameNotSet,
                nameNotSet,
                noFolders,
                saveFailed(Int, String),
                loadFailed(Int, String),
                invalidSlideshowFile(filename: String, message: String)
    }


    var filename:String?
    var name:String? { didSet { hasChanged = true } }
    var slideSeconds:Double = 10.0 { didSet { hasChanged = true } }
    var folderList = [String]() { didSet { hasChanged = true } }
    fileprivate(set) var hasChanged = false


    init()
    {
        reset()
    }

    static func load(_ fromFile: String) throws -> SlideshowData
    {
        do {
            let fileText = try String(contentsOfFile: fromFile, encoding: String.Encoding.utf8)

            let json = JSON(data: fileText.data(using: String.Encoding.utf8, allowLossyConversion: false)!)
            guard json["name"].string != nil else { throw FileError.invalidSlideshowFile(filename: fromFile, message: "Missing name") }

            let slideshowData = SlideshowData()
            slideshowData.name = json["name"].stringValue
            slideshowData.slideSeconds = json["slideSeconds"].doubleValue

            for folderJson in json["folders"].arrayValue {
                slideshowData.folderList.append(folderJson["path"].stringValue)
            }

            slideshowData.hasChanged = false
            return slideshowData
        } catch let f as FileError {
            throw f
        } catch let e as NSError {
            Logger.error("Load failed: \(e.code): \(e.localizedDescription)")
            throw FileError.loadFailed(e.code, e.localizedDescription)
        }
    }

    func save() throws
    {
        guard filename != nil else { throw FileError.filenameNotSet }
        guard name != nil else { throw FileError.nameNotSet }
        guard folderList.count > 0 else { throw FileError.noFolders }
        Logger.info("Saving to \(filename!)")

        // Form up json
        var json = JSON([String: AnyObject]())
        json["name"].string = name!
        json["slideSeconds"].double = slideSeconds

        var jsonFolderList = [AnyObject]()

        for folder in folderList {
            var jsonFolder = [String: AnyObject]()
            jsonFolder["path"] = folder as AnyObject?
            jsonFolderList.append(jsonFolder as AnyObject)
        }
        json["folders"].object = jsonFolderList

        do {

            if !FileManager.default.fileExists(atPath: Preferences.slideshowFolder) {
                Logger.info("Creating slideshow folder: \(Preferences.slideshowFolder)")
                try FileManager.default.createDirectory(atPath: Preferences.slideshowFolder, withIntermediateDirectories: false, attributes: nil)
            }

            try json.rawString()!.write(toFile: filename!, atomically: false, encoding: String.Encoding.utf8)

            hasChanged = false

        } catch let e as NSError {
            Logger.error("Save failed: \(e.code): \(e.localizedDescription)")
            throw FileError.saveFailed(e.code, e.localizedDescription)
        }
    }

    func reset()
    {
        filename = nil
        name = nil
        slideSeconds = 10.0
        folderList = []

        hasChanged = false
    }

    static func getFilenameForName(_ name: String) -> String
    {
        return ((Preferences.slideshowFolder as NSString).appendingPathComponent(name) as NSString).appendingPathExtension(Preferences.SlideshowFileExtension)!
    }
}
