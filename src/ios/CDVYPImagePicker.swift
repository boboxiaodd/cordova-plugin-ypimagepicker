import Foundation
import YPImagePicker
import AVFoundation
import UIKit
import XLActionController
/*
* Notes: The @objc shows that this class & function should be exposed to Cordova.
*/
@objc(CDVYPImagePicker) class CDVYPImagePicker : CDVPlugin {
    @objc(sheet:)
    func sheet(command: CDVInvokedUrlCommand){
        let arg = command.argument(at: 0) as! [AnyHashable : Any]
        let buttons = command.argument(at: 1) as! [[AnyHashable : Any]]
        let actionController = SkypeActionController()
        actionController.settings.statusBar.style = .lightContent
        actionController.backgroundColor = UIColor(hex: arg["bgcolor"] as? String ?? "#ff6b22ff")!
        actionController.title = arg["title"] as? String
        for item in buttons {
            var style:ActionStyle = .default
            if item["style"] as! String == "cancel" {
                style = .cancel
            }
            if item["style"] as! String == "bold" {
                style = .destructive
            }
            actionController.addAction(Action(item["title"] as? String ,style: style,handler: { action in
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: action.data)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }))
        }
        self.viewController.present(actionController, animated: true, completion: nil)
    
    }
    @objc(open:) // Declare your function name.
    func open(command: CDVInvokedUrlCommand) { // write the function code.
        var pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: "picker type error")
        var config = YPImagePickerConfiguration()
        config.library.onlySquare = false
        let arg = command.argument(at: 0) as! [AnyHashable : Any]
        switch(arg["type"] as! String ){
            case "video":
                config.startOnScreen = YPPickerScreen.library
                config.library.mediaType = .video
                config.screens = [.library, .photo]
                config.video.fileType = .mp4
                config.showsCrop = .none
                config.showsVideoTrimmer = false
                config.isScrollToChangeModesEnabled = false
                let picker = YPImagePicker(configuration: config)
                picker.didFinishPicking { [unowned picker] items, _ in
                    if let video = items.singleVideo {
                        let videoInfo = try! video.url.resourceValues(forKeys: [.fileSizeKey])
                        let json = ["url": video.url.absoluteString,
                                    "size": videoInfo.fileSize ?? 0,
                                    "duration":video.asset?.duration.description ?? "0"] as [AnyHashable : Any]
                        pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: json)
                        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
                    }
                    picker.dismiss(animated: true, completion: nil)
                }
                self.viewController.present(picker, animated: true)
                break;
            case "avatar":
                config.startOnScreen = YPPickerScreen.library
                config.library.mediaType = .photo
                config.screens = [.library, .photo]
                config.showsCrop = .rectangle(ratio: 1)
                config.wordings.save = "完成"
                config.showsPhotoFilters = arg["filter"] as? Bool ?? false
                config.targetImageSize = .cappedTo(size: CGFloat(arg["size"] as? Int ?? 500))
                config.isScrollToChangeModesEnabled = false
                config.shouldSaveNewPicturesToAlbum = false
                let picker = YPImagePicker(configuration: config)
                picker.didFinishPicking { [unowned picker] items, _ in
                    if let photo = items.singlePhoto {
                        let fileInfo = self.saveImage(image: photo.image)
                        let json = ["url": fileInfo["path"] ?? "",
                                    "size": fileInfo["size"] ?? 0
                                   ] as [AnyHashable : Any]
                        pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: json)
                        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
                    }
                    picker.dismiss(animated: true, completion: nil)
                }
                self.viewController.present(picker, animated: true)
                break;
            case "photo":
                config.startOnScreen = YPPickerScreen.library
                config.library.mediaType = .photo
                config.screens = [.library, .photo]
                config.showsCrop = .none
                config.targetImageSize = .cappedTo(size: CGFloat(arg["size"] as? Int ?? 1024))
                config.isScrollToChangeModesEnabled = false
                config.showsPhotoFilters = arg["filter"] as? Bool ?? false
                config.shouldSaveNewPicturesToAlbum = false
                let picker = YPImagePicker(configuration: config)
                picker.didFinishPicking { [unowned picker] items, _ in
                    if let photo = items.singlePhoto {
                        let fileInfo = self.saveImage(image: photo.image)
                        let json = ["url": fileInfo["path"] ?? "",
                                    "size": fileInfo["size"] ?? 0,
                                    "width": photo.image.size.width,
                                    "height": photo.image.size.height
                                   ] as [AnyHashable : Any]
                        pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: json)
                        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
                    }
                    picker.dismiss(animated: true, completion: nil)
                }
                self.viewController.present(picker, animated: true)
                break;
            default:
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
        }
    }
    func saveImage(image:UIImage) -> [AnyHashable : Any] {
        let tmpDirectory = FileManager.default.temporaryDirectory;
        let path = tmpDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try! UIImageJPEGRepresentation(image,0.8)?.write(to: path)
        let fileInfo = try! path.resourceValues(forKeys: [.fileSizeKey])
        return ["path":path.absoluteString,"size":fileInfo.fileSize ?? 0]
    }
}
