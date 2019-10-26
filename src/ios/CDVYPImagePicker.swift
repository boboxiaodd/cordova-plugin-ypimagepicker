import Foundation
import YPImagePicker
import AVFoundation
import UIKit
/*
* Notes: The @objc shows that this class & function should be exposed to Cordova.
*/
@objc(CDVYPImagePicker) class CDVYPImagePicker : CDVPlugin {
  @objc(open:) // Declare your function name.
  func open(command: CDVInvokedUrlCommand) { // write the function code.
    var pluginResult = CDVPluginResult (status: CDVCommandStatus_ERROR, messageAs: "picker type error")
    var config = YPImagePickerConfiguration()
    let picker_type = command.argument(at: 0)
    switch(picker_type as! String ){
        case "video":
            config.startOnScreen = YPPickerScreen.library
            config.library.mediaType = .video
            config.screens = [.library, .photo]
            config.video.compression = AVAssetExportPresetHighestQuality
            config.video.fileType = .mp4
            config.showsCrop = .none
            config.showsVideoTrimmer = false
            config.isScrollToChangeModesEnabled = false
            let picker = YPImagePicker(configuration: config)
            picker.didFinishPicking { [unowned picker] items, _ in
                if let video = items.singleVideo {
                    let json = ["url": video.url.path] as [AnyHashable : Any]
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
            config.targetImageSize = .cappedTo(size: 500)
            config.isScrollToChangeModesEnabled = false
            let picker = YPImagePicker(configuration: config)
            picker.didFinishPicking { [unowned picker] items, _ in
                if let photo = items.singleVideo {
                    pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: ["url":photo.url])
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
            config.isScrollToChangeModesEnabled = false
            let picker = YPImagePicker(configuration: config)
            picker.didFinishPicking { [unowned picker] items, _ in
                if let photo = items.singleVideo {
                    pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: ["url":photo.url])
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
}
