import Foundation
import UIKit
import AVFoundation
import AudioToolbox
import Toast_Swift
import RappleProgressHUD

/*
* Notes: The @objc shows that this class & function should be exposed to Cordova.
*/
@objc(CDVInputBar) class CDVInputBar : CDVPlugin,UITextFieldDelegate,FDSoundActivatedRecorderDelegate,AVAudioPlayerDelegate {
    private var inputbar:UIView!
    private var borderView:UIView!
    private var inputbarHeight:CGFloat!
    private var screen:CGRect!
    private var bottomPadding:CGFloat!
    private var tf_panel:UIView!
    private var textfield:MyUITextField!
    private var button_count:Int!
    private var button_width:Int!
    private var voice_button: MyButton?
    private var voice_icon: MyButton?
    private var padding:Int!
    private var audioRecorder:FDSoundActivatedRecorderMock?
    private var audioFilename:URL?
    private var start_time: Int64?
    private var not_delect_sound:Bool?
    private var SoundEffect: AVAudioPlayer!
    private var panelHeight:CGFloat?
    private var panelShow:Bool!
    private var emojiShow:Bool!
    private var moreShow:Bool!
    private var EmojiPanel:UIView!
    private var pagenum1:UIView!
    private var pagenum2:UIView!
    private var MorePanel:UIView!
    private var main_command:CDVInvokedUrlCommand!
    private var sound_command:CDVInvokedUrlCommand!
    private var emoji_prefix:String!
    private var is_chat:Bool!
    private var backdropView:UIView?

    override func pluginInitialize() {
        button_count = 0
        button_width = 30
        inputbarHeight = 46.0
        start_time = 0
        padding = 8
        is_chat = true
        emoji_prefix = "/www/img/emoji/emoji-"
        NotificationCenter.default.removeObserver(self.webView!, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.removeObserver(self.webView!, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self.webView!, name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)
        NotificationCenter.default.removeObserver(self.webView!, name: NSNotification.Name.UIKeyboardDidChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardDidHide), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardDidShow), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
    }

    @objc(show_loadding:)
    func show_loadding(command:CDVInvokedUrlCommand){
        let title = command.argument(at: 0) as! String
        let subtitle = command.argument(at:1) as? String
        SwiftSpinner.show(title).addTapHandler({}, subtitle: subtitle ?? "正在初始化页面")
    }

    @objc(hide_loadding:)
    func hide_loadding(command:CDVInvokedUrlCommand){
        SwiftSpinner.hide();
    }

   @objc(show_toast:)
    func show_toast(command:CDVInvokedUrlCommand){
        let msg = command.argument(at: 0) as! String
    let attributes = RappleActivityIndicatorView.attribute(style: RappleStyle.circle,
                                                               tintColor: .white,
                                                               screenBG: UIColor.black.withAlphaComponent(0.7),
                                                               progressBG: .black,
                                                               progressBarBG: .white,
                                                               progreeBarFill: .red,
                                                               thickness: 4)
        RappleActivityIndicatorView.startAnimatingWithLabel(msg, attributes: attributes)
        let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: "show")
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }
    @objc(hide_toast:)
    func hide_toast(command:CDVInvokedUrlCommand){
        RappleActivityIndicatorView.stopAnimation()
        let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: "hide")
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    //AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if sound_command != nil {
            let json = ["action":"play_end"] as [String:Any]
            let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
            pluginResult?.setKeepCallbackAs(true)
            self.commandDelegate!.send(pluginResult, callbackId: sound_command.callbackId)
            SoundEffect = nil
        }
    }

    @objc(stop_sound:)
    func stop_sound(command:CDVInvokedUrlCommand){
        if SoundEffect != nil {
            SoundEffect?.stop()
            SoundEffect = nil
        }
    }

    func playSound(url:URL){
        do{
            let audioSession = AVAudioSession()
            try! audioSession.setCategory(AVAudioSessionCategoryPlayback)
            SoundEffect = try AVAudioPlayer(contentsOf: url)
            SoundEffect?.volume = 10.0
            SoundEffect?.delegate = self
            SoundEffect?.play()
            let json = ["action":"play_start"] as [String:Any]
            let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
            pluginResult?.setKeepCallbackAs(true)
            self.commandDelegate!.send(pluginResult, callbackId: sound_command.callbackId)
        }catch{
            print("play fail")
        }
    }

    @objc(play_sound:)
    func play_sound(command: CDVInvokedUrlCommand){
        sound_command = command
        if SoundEffect != nil {
            SoundEffect.stop()
            SoundEffect = nil
        }
        let arg = command.argument(at: 0) as! [AnyHashable : Any]
        let url = URL(string: arg["path"] as! String)
        var downloadTask:URLSessionDownloadTask
        downloadTask = URLSession.shared.downloadTask(with: url!){ URL, response, error  in
            self.playSound(url: URL!)
        }
        downloadTask.resume()
        let json = ["action":"play_prepare"] as [String:Any]
        let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
        pluginResult?.setKeepCallbackAs(true)
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    @objc(hide:)
    func hide(command: CDVInvokedUrlCommand){
        if inputbar != nil {
            inputbar.isHidden = true
            sendPluginHeight(height: 0)
            stop_record()
        }
    }
    @objc(show:)
    func show(command: CDVInvokedUrlCommand){
       if inputbar != nil {
            inputbar.isHidden = false
            sendPluginHeight(height: inputbarHeight + bottomPadding)
        }
    }

    func removeInputbar(command:CDVInvokedUrlCommand){
        if self.inputbar != nil {
            self.textfield.removeFromSuperview()
            self.textfield = nil
            self.inputbar.removeFromSuperview()
            self.inputbar = nil
        }
        self.sendPluginHeight(height: 0)
        let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: "inputbar close")
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }

    @objc(close:)
    func close(command: CDVInvokedUrlCommand) { // write the function code
        if self.inputbar == nil { return }
        stop_record()
        if is_chat {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
                self.inputbar.frame = CGRect(x: 0,
                                             y: self.screen.height,
                                             width: self.screen.width,
                                             height: self.inputbarHeight + self.bottomPadding)
            }, completion:{ _ in
                self.removeInputbar(command: command)
            })
        }else{
            backdropView?.removeFromSuperview()
            removeInputbar(command: command)
        }
    }


    @objc(reset:)
    func reset(command: CDVInvokedUrlCommand) {
        print("reset inputbar")
        if textfield != nil {
            textfield.resignFirstResponder()
            hidePanel()
        }
    }

    @objc func backdropTap(recognizer: UITapGestureRecognizer){
        self.close(command: main_command)
    }

    @objc(create:) // Declare your function name.
    func create(command: CDVInvokedUrlCommand) { // write the function code.
        panelShow = false
        emojiShow = false
        moreShow = false
        if (inputbar != nil) {
            return
        }
        main_command = command
        let arg = command.argument(at: 0) as! [AnyHashable : Any]
        if arg["emoji_prefix"] != nil {
            emoji_prefix = arg["emoji_prefix"] as? String
        }
        bottomPadding = UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 35.0
        screen  = UIScreen.main.bounds
        is_chat =  arg["is_chat"] as? Bool ?? true
        let is_focus = arg["focus"] as? Bool ?? true
        if !is_chat && is_focus { //显示backdrop view
            backdropView = UIView(frame: CGRect(x: 0, y: 0, width: Int(screen.width), height: Int(screen.height)))
            backdropView?.backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.5)
            backdropView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backdropTap)))
            self.viewController.view.addSubview(backdropView!)
        }

        inputbar = UIView(frame: CGRect(x: 0,
                                        y: is_chat ? screen.height :  screen.height - (bottomPadding + inputbarHeight),
                                    width: screen.width,
                                   height: inputbarHeight + bottomPadding));
        borderView = UIView(frame: CGRect(x: 0,y: 0,width: screen.width,height: 1))
        borderView.backgroundColor = UIColor(hex: "#eeeeeeff")
        inputbar.addSubview(borderView)
        inputbar.backgroundColor =  UIColor(hex: arg["bgcolor"] as? String ?? "#f7f7f8ff")


        var textfield_width = screen.width

        if is_chat {
            textfield_width = screen.width - CGFloat((button_width * 3 + 20 + padding * 3))
            voice_icon = addbutton(command: command, icon: "ib_voice", action: #selector(voiceTap), x: 10)
            let posx = Int(screen.width) - (button_width * 2 + 10 + padding)
            let _ = addbutton(command: command,
                      icon: "ib_face",
                      action: #selector(faceTap),
                      x: posx)
            let _ = addbutton(command: command, icon: "ib_more", action: #selector(moreTap), x: Int(screen.width) - button_width - 10)
            tf_panel = UIView(frame: CGRect(x: button_width + 10 + padding ,
                                                y: padding,
                                                width: Int(textfield_width),
                                                height: button_width))
            tf_panel.backgroundColor = UIColor.white

            voice_button = MyButton(frame: tf_panel.frame, command: command)
            voice_button?.backgroundColor = UIColor.white
            voice_button?.layer.cornerRadius = 5
            voice_button?.setTitle("按住 说话", for: .normal)
            voice_button?.setTitle("上滑 取消", for: .highlighted)
            voice_button?.setTitleColor(UIColor.black, for: .normal)
            voice_button?.setTitleColor(UIColor.red, for: .focused)
            voice_button?.titleLabel?.textAlignment = .center
            voice_button?.addTarget(self, action: #selector(record_start), for: .touchDown)
            voice_button?.addTarget(self, action: #selector(record_end), for: .touchUpInside)
            voice_button?.addTarget(self, action: #selector(record_cancel), for: .touchUpOutside)
            voice_button?.isHidden = true

            tf_panel.layer.cornerRadius = 5
            inputbar.addSubview(tf_panel)
            inputbar.addSubview(voice_button!)
            textfield = MyUITextField(frame: CGRect(x: 5 ,
                                                    y: 0,
                                                    width: Int(tf_panel.frame.width) - 10,
                                                    height: Int(tf_panel.frame.height)),command: command)
            initFacePanel(total: 48,command: command)
            initMorePanel(command:command)
            textfield.returnKeyType = .send
        }else{
            tf_panel = UIView(frame: CGRect(x: 10 ,
                                                y: padding,
                                                width: Int(textfield_width) - 20,
                                                height: button_width))
            tf_panel.backgroundColor = UIColor.white
            tf_panel.layer.cornerRadius = 5
            inputbar.addSubview(tf_panel)
            textfield = MyUITextField(frame: CGRect(x: 5,
                                                    y: 0,
                                                    width: Int(tf_panel.frame.width) - 10,
                                                    height: Int(tf_panel.frame.height)),command: command)
            if is_focus {
                textfield.returnKeyType = .done
            }else{
                textfield.returnKeyType = .send
            }
        }
        textfield.delegate = self
        textfield.keyboardAppearance = .light
        textfield.textColor = UIColor.black
        textfield.attributedPlaceholder = NSAttributedString(
            string: arg["placeholder"] as? String ?? "输入聊天内容",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.gray])
        textfield.text = arg["text"] as? String ?? ""

        tf_panel.addSubview(textfield)


        self.viewController.view.addSubview(inputbar);
        if is_chat {
            //动画显示
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
                self.inputbar.frame = CGRect(x: 0,
                                             y: self.screen.height - (self.bottomPadding + self.inputbarHeight),
                                             width: self.screen.width,
                                             height: self.inputbarHeight + self.bottomPadding)
            }, completion: nil)
        }
        if !is_chat && is_focus {
            textfield.becomeFirstResponder()
        }
        let json = ["action":"inputbarShow","height": inputbarHeight + bottomPadding ] as [String:Any]
        let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
        pluginResult?.setKeepCallbackAs(true)
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
    }



    @objc func onKeyboardDidHide(_ sender:NSNotification){
        sendAction(action: "onKeyboardDidHide")
    }
    @objc func onKeyboardDidShow(_ sender:NSNotification){
        sendAction(action: "onKeyboardDidShow")
    }
    @objc func onKeyboardWillShow(notification: NSNotification) {
        if (inputbar != nil) {
            guard let keyboardNotification = KeyboardNotification(from: notification) else { return }
            let newFrame = CGRect(x: 0,
                                  y: screen.height - inputbarHeight - keyboardNotification.endFrame.height,
                                  width: screen.width,
                                  height: inputbarHeight)
            inputbar.frame = newFrame
            //隐藏表情
            self.hideEmoji()
            self.hideMore()
            self.panelShow = false
            sendPluginHeight(height: keyboardNotification.endFrame.height + inputbarHeight!)
            sendAction(action: "onKeyboardWillShow")
        }
    }
    @objc func onKeyboardWillHide(notification: NSNotification) {
        if inputbar != nil {
            let newFrame = CGRect(x: 0,
                                  y: screen.height - ( bottomPadding + inputbarHeight),
                                  width: screen.width,
                                  height: inputbarHeight + bottomPadding)
            inputbar.frame = newFrame
            sendPluginHeight(height: inputbarHeight + bottomPadding)
            sendAction(action: "onKeyboardWillHide")
        }
    }

    private func setButtonImage(button:MyButton,image:String){
        let icon = UIImage(named: image)
        let tintIcon = icon?.withRenderingMode(.alwaysTemplate)
        button.setImage(tintIcon, for: .normal)
    }
    private func addbutton(command: CDVInvokedUrlCommand,icon:String,action:Selector,x:Int) -> MyButton{
        let button = MyButton(frame: CGRect(x: x,y: padding, width: button_width, height: button_width),
                              command: command)
        setButtonImage(button: button, image: icon)
        button.tintColor = UIColor.black
        button.addTarget(self, action: action, for: .touchUpInside)
        inputbar.addSubview(button)
        return button
    }
    func hideVoice(){
        setButtonImage(button: voice_icon!, image: "ib_voice")
        tf_panel.isHidden = false
        voice_button?.isHidden = true
    }
    @objc func voiceTap(_ button:MyButton){
        if !tf_panel.isHidden {
            setButtonImage(button: button, image: "ib_keyboard")
            tf_panel.isHidden = true
            voice_button?.isHidden = false
            hidePanel()
            textfield.resignFirstResponder()
        }else{
            hideVoice();
            textfield.becomeFirstResponder()
        }
    }
    func sendAction(action:String){
        if main_command != nil {
            let json = ["action":action] as [String:Any]
            let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
            pluginResult?.setKeepCallbackAs(true)
            self.commandDelegate!.send(pluginResult, callbackId: main_command.callbackId)
        }
    }
    func sendPluginHeight(height:CGFloat){
        if main_command != nil {
            let json = ["action":"onResize","height":height] as [String:Any]
            let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
            pluginResult?.setKeepCallbackAs(true)
            self.commandDelegate!.send(pluginResult, callbackId: main_command.callbackId)
        }
    }

    func hidePanel(){

        if panelShow {
            hideEmoji()
            hideMore()
            sendPluginHeight(height: inputbarHeight! + bottomPadding!)
            UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseOut, animations: {
                self.inputbar.frame = CGRect(x: 0,
                                             y: self.screen.height - (self.bottomPadding + self.inputbarHeight),
                                             width: self.screen.width,
                                             height: self.inputbarHeight + self.bottomPadding)
            }, completion: { _ in
                self.panelShow = false
            })
        }
    }
    func showPanel(){
        if !panelShow {
            sendPluginHeight(height: inputbarHeight! + bottomPadding! + panelHeight!)
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
                self.inputbar.frame = CGRect(x: 0,
                                             y: self.screen.height - (self.bottomPadding + self.inputbarHeight) - self.panelHeight!,
                                             width: self.screen.width,
                                             height: self.inputbarHeight + self.bottomPadding + self.panelHeight!)
            }, completion: { _ in
                self.panelShow = true
            })
        }
    }

    func showEmoji(){
        textfield.resignFirstResponder()
        EmojiPanel?.isHidden = false
        pagenum1?.isHidden = false
        pagenum2?.isHidden = false
        emojiShow = true
    }
    func hideEmoji(){
        EmojiPanel?.isHidden = true
        pagenum1?.isHidden = true
        pagenum2?.isHidden = true
        emojiShow = false
    }
    func showMore(){
        textfield.resignFirstResponder()
        MorePanel?.isHidden = false
        moreShow = true
    }
    func hideMore(){
        MorePanel?.isHidden = true
        moreShow = false
    }

    @objc func faceTap(_ button:MyButton){
        if emojiShow {
            hidePanel()
        }else{
            hideVoice()
            hideMore()
            showEmoji()
            showPanel()
        }
        print("face tap")
    }


    @objc func moreTap(_ button:MyButton){
        print("more tap")
        if moreShow! {
            hidePanel()
        }else{
            hideVoice()
            hideEmoji()
            showMore()
            showPanel()
        }
    }

    func soundActivatedRecorderDidAbort(_ recorder: FDSoundActivatedRecorder) {
        SwiftSpinner.hide()
        print("soundActivatedRecorderDidAbort")
    }
    func soundActivatedRecorderDidTimeOut(_ recorder: FDSoundActivatedRecorder) {
        print("soundActivatedRecorderDidTimeOut")
    }
    func soundActivatedRecorderDidStartRecording(_ recorder: FDSoundActivatedRecorder) {
        start_time = Date().millisecondsSince1970
        not_delect_sound = false
        SwiftSpinner.shared.titleLabel.text = "正在录音\n00:00"
        print("soundActivatedRecorderDidStartRecording")
    }
    func soundNotDelectSound(_ flag: Bool) {
        if flag {
            not_delect_sound = true
            SwiftSpinner.shared.titleLabel.text = "未检测到声音"
        }else{
            not_delect_sound = false
        }
    }

    func soundActivatedRecorderDidFinishRecording(_ recorder: FDSoundActivatedRecorder, andSaved file: URL) {
        let diff = Date().millisecondsSince1970 - start_time!

        let tmpDirectory = FileManager.default.temporaryDirectory;
        let outputURL = tmpDirectory.appendingPathComponent("\(UUID().uuidString).mp3")
        let outputPath = outputURL.path

        let converter = ExtAudioConverter()
        converter.inputFilePath = file.path;
        converter.outputFilePath = outputPath;
        converter.outputFormatID = kAudioFormatMPEGLayer3;
        if converter.convert() {
            let mp3Url  = URL(fileURLWithPath: outputPath)
            let audioInfo = try! mp3Url.resourceValues(forKeys: [.fileSizeKey])
            let json = ["action":"audio",
                        "url": outputPath ,
                        "size": audioInfo.fileSize ?? 0,
                        "duration": Double(diff) / 1000.0 ] as [String : Any]
            let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
            pluginResult?.setKeepCallbackAs(true)
            self.commandDelegate!.send(pluginResult, callbackId: (recorder as! FDSoundActivatedRecorderMock).command?.callbackId)
        }
        else {
            print("conver fail")
        }
        audioRecorder = nil
    }

    func drawSample(currentLevel: Float) {
        if not_delect_sound! {
            return
        }
        if start_time! > 0 {
            let diff = Date().millisecondsSince1970 - start_time!
            let sec = diff / Int64(1000.0)
            let micsec = (diff % Int64(1000.0)/10)
            SwiftSpinner.shared.titleLabel.text = "正在录音\n\(sec):\(micsec)"
        }
    }


    @objc func record_start(_ button:MyButton){
        print("record_start")
        AudioServicesPlaySystemSound(SystemSoundID(1519))
        start_time = 0
        audioRecorder = FDSoundActivatedRecorderMock(command: button.command!)
        audioRecorder?.delegate = self
        audioRecorder?.timeoutSeconds = 120.0
        audioRecorder?.intervalCallback = {currentLevel in self.drawSample(currentLevel: currentLevel)}

        let audioSession = AVAudioSession.sharedInstance()
        _ = try? audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
        _ = try? audioSession.setActive(true)
        audioRecorder?.startListening()
        SwiftSpinner.show("正在检测声音").addTapHandler({}, subtitle: "松开结束，上滑取消")
    }
    @objc func record_end(_ button:MyButton){
        if start_time == 0 {
            audioRecorder?.abort()
            SwiftSpinner.hide()
            self.viewController.view!.makeToast("未检测到声音，录制取消",position: .center)
            return
        }
        audioRecorder?.stopAndSaveRecording()
        SwiftSpinner.hide()
    }

    func stop_record(){
        if audioRecorder != nil {
            audioRecorder!.abort()
            self.viewController.view!.makeToast("录制取消",position: .center)
            SwiftSpinner.hide()
        }
    }

    @objc func record_cancel(_ button:MyButton){
        stop_record()
    }

    @objc func leftSwipe(){
        print("leftSwipe")
        let screen_width = CGFloat(screen.width)
        let rect = self.EmojiPanel.frame
        if Double(rect.origin.x) == 0.0 {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                    self.EmojiPanel.frame = CGRect(x: -screen_width,
                                                   y: rect.origin.y,
                                                   width: rect.size.width,
                                                   height: rect.size.height)
            }, completion: {_ in
                self.pagenum2.backgroundColor = UIColor.darkGray
                self.pagenum1.backgroundColor = UIColor.lightGray
            })
        }
    }
    @objc func rightSwipe(){
        print("rightSwipe")
        let screen_width = CGFloat(screen.width)
        let rect = self.EmojiPanel.frame
        if Double(rect.origin.x) == -Double(screen_width) {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                    self.EmojiPanel.frame = CGRect(x: 0.0,
                                                   y: rect.origin.y,
                                                   width: rect.size.width,
                                                   height: rect.size.height)
            }, completion: {_ in
                self.pagenum2.backgroundColor = UIColor.lightGray
                self.pagenum1.backgroundColor = UIColor.darkGray
            })
        }
    }
    @objc func emojiTap(button:UIButton){
        print("emoji \(button.tag) tap")
        let command = (button as! MyButton).command
        let json = ["action":"emoji",
                    "index": button.tag] as [String:Any]
        let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
        pluginResult?.setKeepCallbackAs(true)
        self.commandDelegate!.send(pluginResult, callbackId: command?.callbackId)
    }
    @objc func moreBtnTap(button:UIButton){
        let command = (button as! MyButton).command
        let json = ["action": (button as! MyButton).action!] as [String:Any]
        let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
        pluginResult?.setKeepCallbackAs(true)
        self.commandDelegate!.send(pluginResult, callbackId: command?.callbackId)
    }
    func initMorePanel(command:CDVInvokedUrlCommand){
        let arg = command.argument(at: 1) as! [[AnyHashable : Any]]
        MorePanel = UIView(frame: CGRect(x: 0.0,
                                         y: Double(inputbarHeight),
                                        width: Double(screen.width),
                                        height: Double(panelHeight!)))
        MorePanel.isHidden = true
        inputbar.addSubview(MorePanel)
        let button_width = Double(screen.width - 50.0 )/4
        var count = 0.0;
        for item in arg {
            let btn = MyButton(frame: CGRect(x: 10.0 + (button_width + 10.0) * count , y: 10.0, width: button_width, height: button_width),command: command,action:item["action"] as! String)
            btn.setImage(UIImage(named: item["icon"] as! String), for: .normal)
            btn.imageEdgeInsets = UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
            btn.setBackgroundImage(UIImage(color: UIColor.lightGray), for: .normal)
            btn.setBackgroundImage(UIImage(color: UIColor.gray), for: .highlighted)
            btn.layer.cornerRadius = 8.0
            btn.layer.masksToBounds = true
            btn.addTarget(self, action: #selector(moreBtnTap), for: .touchUpInside)
            MorePanel.addSubview(btn)
            let label = UILabel(frame: CGRect(x: 10.0 + (button_width + 10.0) * count , y: 10.0 + button_width + 5.0, width: button_width, height: 20.0))
            label.text = item["title"] as? String
            label.textColor = UIColor.gray
            label.textAlignment = .center
            MorePanel.addSubview(label)
            count += 1.0
        }
    }
    func initFacePanel(total:Int,command:CDVInvokedUrlCommand){
        //TODO 通过total计算分的页面
        let imageWidth:Double = (Double(screen.width) - 80.0) / 8.0
        panelHeight = CGFloat(imageWidth * 3.0 + 28.0)
        let paddingLeft = 10.0
        EmojiPanel = UIView(frame: CGRect(x: 0.0,
                                              y: Double(inputbarHeight),
                                              width: Double(screen.width * 2.0),
                                              height: Double(panelHeight!)))
        EmojiPanel.isHidden = true
        inputbar.addSubview(EmojiPanel)

        //创建分页指示
        pagenum1 = UIView(frame: CGRect(x: Double(screen.width/2 - 12), y: Double(inputbarHeight) + (imageWidth + 5) * 3.0 + 2.0 , width: 8.0, height: 8.0))
        pagenum1.layer.cornerRadius = 4
        pagenum1.layer.masksToBounds = true
        pagenum1.backgroundColor = UIColor.darkGray
        pagenum1.isHidden = true
        inputbar.addSubview(pagenum1)

        pagenum2 = UIView(frame: CGRect(x: Double(screen.width/2 + 12), y: Double(inputbarHeight) + (imageWidth + 5) * 3.0 + 2.0, width: 8.0, height: 8.0))
        pagenum2.layer.cornerRadius = 4
        pagenum2.layer.masksToBounds = true
        pagenum2.backgroundColor = UIColor.lightGray
        pagenum2.isHidden = true
        inputbar.addSubview(pagenum2)


        let left = UISwipeGestureRecognizer(target : self, action : #selector(leftSwipe))
        left.direction = .left
        EmojiPanel.addGestureRecognizer(left)

        let right = UISwipeGestureRecognizer(target : self, action : #selector(rightSwipe))
        right.direction = .right
        EmojiPanel.addGestureRecognizer(right)


        let BundleDirectory = Bundle.main.bundlePath
        var line = -1
        var page:Double = 0.0
        for i in 1...total {
            let path = "\(BundleDirectory)\(emoji_prefix!)\(i).png"
            let img = UIImage(contentsOfFile: path)
            if i % (total/2 + 1) == 0 {
                line = -1
                page = Double(screen.width)
            }
            if (i-1) % 8 == 0 {
                line += 1
            }

            let imgview = MyButton(frame: CGRect(x: page + paddingLeft + (imageWidth + 10.0) * Double((i-1) % 8),
                                                 y: Double(imageWidth + 5) * Double(line), width: imageWidth, height: imageWidth),command: command)
            imgview.setImage(img, for: .normal)
            imgview.tag = i
            imgview.addTarget(self, action: #selector(emojiTap), for: .touchUpInside)
            imgview.imageView?.contentMode = .scaleAspectFit
            EmojiPanel.addSubview(imgview)
        }
    }


    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        let command = (textfield!).command!
        let json = ["action": "send",
                    "text": textfield.text ?? ""] as [String : Any]
        textfield.text = ""
        let pluginResult = CDVPluginResult (status: CDVCommandStatus_OK, messageAs: json)
        pluginResult?.setKeepCallbackAs(true)
        self.commandDelegate!.send(pluginResult, callbackId: command.callbackId)
        return true
    }
}

class MyUITextField:UITextField {

    var command : CDVInvokedUrlCommand? = nil

    convenience init(frame: CGRect,command:CDVInvokedUrlCommand) {
        self.init(frame: frame)
        self.command = command
    }
}

extension UIColor {
    public convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x000000ff) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}

class MyButton : UIButton {
    var command : CDVInvokedUrlCommand? = nil
    var action: String? = nil
    convenience init(frame: CGRect,command:CDVInvokedUrlCommand) {
        self.init(frame: frame)
        self.command = command
    }
    convenience init(frame: CGRect,command:CDVInvokedUrlCommand,action:String) {
        self.init(frame: frame)
        self.command = command
        self.action = action
    }
}

public extension UIImage {
    convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
      }
}


extension Date {
    var millisecondsSince1970:Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }

    init(milliseconds:Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}


class FDSoundActivatedRecorderMock: FDSoundActivatedRecorder {
    var intervalCallback: (Float)->() = {_ in}
    var command : CDVInvokedUrlCommand? = nil
    override func interval(currentLevel: Float) {
        self.intervalCallback(currentLevel);
        super.interval(currentLevel: currentLevel);
    }

    convenience init(command:CDVInvokedUrlCommand) {
        self.init();
        self.command = command
    }
}
