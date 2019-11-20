import Foundation
import Gallery
import AVFoundation
import AVKit
import UIKit
import XLActionController
import CropViewController
import RappleProgressHUD
import SKPhotoBrowser
/*
* Notes: The @objc shows that this class & function should be exposed to Cordova.
*/


open class MySKPhotoBrowser: SKPhotoBrowser {
    open override var supportedInterfaceOrientations: UIInterfaceOrientationMask{
        get{
            return .portrait
        }
    }
    open override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent // white statusbar, .default is black
    }

}

@objc(CDVYPImagePicker) class CDVYPImagePicker : CDVPlugin, GalleryControllerDelegate,CropViewControllerDelegate {
    private var main_command: CDVInvokedUrlCommand?
    private var imagepicker_type:String!

    func encodeVideo(at videoURL: URL, completionHandler: ((URL?, Error?) -> Void)?)  {
        let avAsset = AVURLAsset(url: videoURL, options: nil)

        let startDate = Date()

        //Create Export session
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough) else {
            completionHandler?(nil, nil)
            return
        }

        //Creating temp path to save the converted video
        let tmpDirectory = FileManager.default.temporaryDirectory;
        let filePath = tmpDirectory.appendingPathComponent("\(UUID().uuidString).mp4")

        exportSession.outputURL = filePath
        exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = true
        let start = CMTimeMakeWithSeconds(0.0, 0)
        let range = CMTimeRangeMake(start, avAsset.duration)
        exportSession.timeRange = range

        exportSession.exportAsynchronously(completionHandler: {() -> Void in
            switch exportSession.status {
            case .failed:
                print(exportSession.error ?? "NO ERROR")
                completionHandler?(nil, exportSession.error)
            case .cancelled:
                print("Export canceled")
                completionHandler?(nil, nil)
            case .completed:
                //Video conversion finished
                let endDate = Date()

                let time = endDate.timeIntervalSince(startDate)
                print(time)
                print("Successful! \(exportSession.maxDuration.seconds)")
                print(exportSession.outputURL ?? "NO OUTPUT URL")
                completionHandler?(exportSession.outputURL, nil)

                default: break
            }

        })
    }

    @objc(mov2mp4:)
    func mov2mp4(command:CDVInvokedUrlCommand){
        let arg = command.argument(at: 0) as! [AnyHashable : Any]
        let path = URL(fileURLWithPath: arg["path"] as! String)
        encodeVideo(at: path){ url,error in
            if url == nil {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "covert fail")
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }else{
                do {
                    try FileManager.default.removeItem(at: path)
                } catch {
                    print("remove old file error")
                }
                let json = ["url":url!.absoluteString] as [AnyHashable:String]
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: json)
                self.commandDelegate!.send(pluginResult, callbackId: command.callbackId);
            }
        }

    }

    @objc(photo_browser:)
    func photo_browser(command:CDVInvokedUrlCommand){
        let arg = command.argument(at: 0) as! [String]
        let idx = command.argument(at: 1)
        var images = [SKPhoto]()
        for url in arg {
            let photo = SKPhoto.photoWithImageURL(url)
            photo.shouldCachePhotoURLImage = true
            images.append(photo);
        }
        let browser = MySKPhotoBrowser(photos: images)
        SKPhotoBrowserOptions.displayStatusbar = true
        browser.initializePageIndex(idx as? Int ?? 0)
        self.viewController.present(browser, animated: true, completion: nil)
    }

    @objc(sheet:)
    func sheet(command: CDVInvokedUrlCommand){
        let arg = command.argument(at: 0) as! [AnyHashable : Any]
        let buttons = command.argument(at: 1) as! [[AnyHashable : Any]]
        let actionController = PeriscopeActionController()
        actionController.settings.statusBar.style = .lightContent
        actionController.headerData = arg["title"] as? String ?? "请选择"
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
        let bottomPadding = UIApplication.shared.keyWindow!.safeAreaInsets.bottom
        if  bottomPadding > 0 {
            print("\(actionController.collectionView.bounds.height) \(UIScreen.main.bounds.height) \(bottomPadding)")
            let bottomView = UIView(frame: CGRect(x: 0.0,
                                                  y: actionController.collectionView.bounds.height - bottomPadding - 5.0,
                                                  width: UIScreen.main.bounds.width,
                                                  height: bottomPadding + 5.0))
            bottomView.backgroundColor = .white
            actionController.collectionView.backgroundView?.addSubview(bottomView)
        }
        actionController.onConfigureCellForAction = { cell, action, indexPath in
            cell.setup(action.data, detail: nil, image: nil)
            cell.separatorView?.isHidden = indexPath.item == actionController.collectionView.numberOfItems(inSection: indexPath.section) - 1
            cell.alpha = action.enabled ? 1.0 : 0.5
            cell.actionTitleLabel?.textColor = action.style == .destructive ? UIColor(red: 210/255.0, green: 77/255.0, blue: 56/255.0, alpha: 1.0) : UIColor.darkGray
        }
        self.viewController.present(actionController, animated: true, completion: nil)

    }

    @objc(play:)
    func play(command:CDVInvokedUrlCommand){
        let path = command.argument(at: 0) as! String
        let controller = AVPlayerViewController()
        controller.entersFullScreenWhenPlaybackBegins = true
        controller.videoGravity = AVLayerVideoGravity.resizeAspectFill.rawValue
        let audioSession = AVAudioSession()
        try! audioSession.setCategory(AVAudioSessionCategoryPlayback)
        controller.player = AVPlayer(url: URL(fileURLWithPath: path))
        self.viewController.present(controller, animated: true, completion: {
            controller.player?.play()
        })
    }

    func galleryController(_ controller: GalleryController, didSelectVideo video: Video) {
        RappleActivityIndicatorView.startAnimatingWithLabel("处理中...")
        video.fetchAVAsset{asset in
            let videourl = (asset as! AVURLAsset).url
            let ext = videourl.pathExtension
            let destpath  = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
            try! FileManager.default.copyItem(atPath: videourl.path, toPath: destpath.path)
            let videoInfo = try! destpath.resourceValues(forKeys: [.fileSizeKey])
            let json = ["url": destpath.absoluteString ,
                        "size": videoInfo.fileSize ?? 0 ,
                        "duration": asset!.duration.seconds ] as [AnyHashable : Any]
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: json)
            pluginResult?.setKeepCallbackAs(true)
            self.commandDelegate!.send(pluginResult, callbackId: self.main_command?.callbackId);
            RappleActivityIndicatorView.stopAnimation()
            controller.dismiss(animated: true, completion: nil)
        }
    }

    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        let arg = main_command!.argument(at: 0) as! [AnyHashable : Any]
        let size = CGFloat(arg["size"] as? Int ?? 512)
        let newImage = resizeImage(image: image, size: size)
        let fileInfo = self.saveImage(image: newImage)
        let json = ["url": fileInfo["path"] ?? "",
                    "size": fileInfo["size"] ?? 0,
                    "width": newImage.size.width,
                    "height": newImage.size.height
                   ] as [AnyHashable : Any]
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: json)
        pluginResult?.setKeepCallbackAs(true)
        self.commandDelegate!.send(pluginResult, callbackId: self.main_command?.callbackId);
        cropViewController.dismiss(animated: true, completion: nil)
    }

    func galleryController(_ controller: GalleryController, didSelectImages images: [Image]) {
        RappleActivityIndicatorView.startAnimatingWithLabel("请稍等...")
        if imagepicker_type == "avatar" {
            controller.dismiss(animated: false){
                images[0].resolve{image in
                    let cropViewController = CropViewController(image: image!)
                    cropViewController.aspectRatioLockEnabled = true
                    cropViewController.aspectRatioPreset = .presetSquare
                    cropViewController.aspectRatioPickerButtonHidden = true
                    cropViewController.resetButtonHidden = true
                    cropViewController.delegate = self
                    self.viewController.present(cropViewController, animated: true){
                        RappleActivityIndicatorView.stopAnimation()
                    }
                }
            }
        }else{
            for item in images {
                item.resolve{ img in
                    let newImage = self.resizeImage(image: img!, size: 1024)
                    let fileInfo = self.saveImage(image: newImage)
                    let json = ["url": fileInfo["path"] ?? "",
                                "size": fileInfo["size"] ?? 0,
                                "width": img!.size.width,
                                "height": img!.size.height
                               ] as [AnyHashable : Any]
                    let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: json)
                    pluginResult?.setKeepCallbackAs(true)
                    self.commandDelegate!.send(pluginResult, callbackId: self.main_command?.callbackId);
                    RappleActivityIndicatorView.stopAnimation()
                }
            }
            controller.dismiss(animated: true, completion: nil)
        }
    }
    func galleryControllerDidCancel(_ controller: GalleryController) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "cancel")
        pluginResult?.setKeepCallbackAs(true)
        self.commandDelegate!.send(pluginResult, callbackId: self.main_command?.callbackId);
        controller.dismiss(animated: true, completion: nil)
    }
    func galleryController(_ controller: GalleryController, requestLightbox images: [Image]) {
        print(images)
    }

    @objc(open:) // Declare your function name.
    func open(command: CDVInvokedUrlCommand) { // write the function code.
        self.main_command = command
        let arg = command.argument(at: 0) as! [AnyHashable : Any]
        imagepicker_type = arg["type"] as? String ?? "photo"
        switch(imagepicker_type){
            case "video":
                Config.Font.Text.bold = UIFont.systemFont(ofSize: 14.0, weight: .bold)
                Config.Camera.recordLocation = false
                Config.tabsToShow = [.videoTab]
                Config.initialTab = .videoTab
                Config.VideoEditor.savesEditedVideoToLibrary = false
                Config.VideoEditor.maximumDuration = 20.0
                let gallery = GalleryController()
                gallery.delegate = self
                self.viewController.present(gallery, animated: true)
                break;
            case "avatar":
                Config.Font.Text.bold = UIFont.systemFont(ofSize: 14.0, weight: .bold)
                Config.Camera.recordLocation = true
                Config.Camera.imageLimit = 1
                Config.tabsToShow = [.imageTab, .cameraTab]
                Config.initialTab = .imageTab
                let gallery = GalleryController()
                gallery.delegate = self
                self.viewController.present(gallery, animated: true)
                break
            case "photo":
                Config.Font.Text.bold = UIFont.systemFont(ofSize: 14.0, weight: .bold)
                Config.Camera.recordLocation = false
                Config.Camera.imageLimit = arg["max"] as? Int ?? 5
                Config.tabsToShow = [.imageTab, .cameraTab]
                Config.initialTab = .imageTab
                let gallery = GalleryController()
                gallery.delegate = self
                self.viewController.present(gallery, animated: true)
                break
            default:
                print("bad type")
        }
    }
    func resizeImage(image:UIImage,size:CGFloat) -> UIImage {
        let newsize = cappedSize(for: image.size, cappedAt: size)
        UIGraphicsBeginImageContextWithOptions(newsize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: .zero, size: newsize))
        return UIGraphicsGetImageFromCurrentImageContext()!
    }

    func cappedSize(for size: CGSize, cappedAt: CGFloat) -> CGSize {
        var cappedWidth: CGFloat = 0
        var cappedHeight: CGFloat = 0
        if size.width > size.height {
            // Landscape
            let heightRatio = size.height / size.width
            cappedWidth = min(size.width, cappedAt)
            cappedHeight = cappedWidth * heightRatio
        } else if size.height > size.width {
            // Portrait
            let widthRatio = size.width / size.height
            cappedHeight = min(size.height, cappedAt)
            cappedWidth = cappedHeight * widthRatio
        } else {
            // Squared
            cappedWidth = min(size.width, cappedAt)
            cappedHeight = min(size.height, cappedAt)
        }
        return CGSize(width: cappedWidth, height: cappedHeight)
    }
    func saveImage(image:UIImage) -> [AnyHashable : Any] {
        let tmpDirectory = FileManager.default.temporaryDirectory;
        let path = tmpDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try! UIImageJPEGRepresentation(image,0.8)?.write(to: path)
        let fileInfo = try! path.resourceValues(forKeys: [.fileSizeKey])
        return ["path":path.absoluteString,"size":fileInfo.fileSize ?? 0]
    }
}
