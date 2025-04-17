//
//  ViewController.swift
//  sdkTest
//
//  Created by li xiaoming on 2023/12/12.
//

import UIKit
import HyphenateChat

//let Appkey = "sandbox-dee1#wdtest"
//let Appkey = "1116221125119117#ldnl"
//let Appkey = "41117440#383391"
//let Appkey = "52117440#955012"
//let Appkey = "81381637#1096661"
//let Appkey = "81446724#514456"


let Appkey = "easemob-demo#chatdemoui"
let useSandbox = false
let useAppId = false

var msgStrings = [
            "豫章故郡，洪都新府2。星分翼轸，地接衡庐",
            "襟三江而带五湖4，控蛮荆而引瓯越",
            "物华天宝，龙光射牛斗之墟6；人杰地灵，徐孺下陈蕃之榻",
            "襟三江而带五湖4，控蛮荆而引瓯越",
            "都督阎公之雅望，棨戟遥临；宇文新州之懿范，襜帷暂驻",
            "雄州雾列8，俊采星驰9。台隍枕夷夏之交10，宾主尽东南之美",
            "都督阎公之雅望，棨戟遥临；宇文新州之懿范，襜帷暂驻",
            "十旬休假13，胜友如云；千里逢迎14，高朋满座。腾蛟起凤，孟学士之词宗",
            "紫电青霜，王将军之武库16。家君作宰，路出名区；童子何知，躬逢胜饯",
            "时维九月，序属三秋18。潦水尽而寒潭清，烟光凝而暮山紫。俨骖騑于上路",
            "19，访风景于崇阿。临帝子之长洲，得天人之旧馆20。层峦耸翠，上出重霄；飞阁流丹，下临无地21。"
    ]

class ViewController: UIViewController, UINavigationControllerDelegate {

    @IBOutlet weak var userIdField: UITextField!
    @IBOutlet weak var pwdField: UITextField!
    
    @IBOutlet weak var conversationIdField: UITextField!
    @IBOutlet weak var textField: UITextField!
    
    @IBOutlet weak var logView: UITextView!
    var messageId: String? = "1393146528809355220"
    var messageCount: Int = 0
    var tryTime = 0;
    var chatroomId = "268846180139015"
    var groupId = "277822917640195"
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        initView()
        initSDK()
    }
    deinit {
    }
    public func initView() {
        self.pwdField.text = "1"
        self.userIdField.text = "lxm"
        self.conversationIdField.text = "lxm2"
        self.textField.text = "hello world"
    }
    func loginWithPwd() {
        
        if let userId = userIdField.text,
           let pwd = pwdField.text {
            EMClient.shared().login(withUsername: userId, password: pwd) { [weak self] (aUsername, aError) in
                if let error = aError {
                    self?.printLog("login error: \(error.errorDescription ?? "")")
//                    if error.code == .userNotFound {
//                        EMClient.shared().register(withUsername: userId, password: pwd) { u, e in
//                            EMClient.shared().login(withUsername: userId, password: pwd)
//                        }
//                    }
                    
                } else {
                    self?.printLog("login success")
                    let conversations = EMClient.shared().chatManager?.getAllConversations()
                    self?.printLog("conversations count:\(conversations?.count ?? 0)")
                    if let conversation = EMClient.shared().chatManager?.getConversationWithConvId(self?.conversationIdField.text ?? "") {
                        self?.printLog("conversationid:\(conversation.conversationId),message count:\(conversation.messagesCount)")
                    }
                }
            }
        }
    }
    @IBAction func loginAction(_ sender: Any) {
        //loginWith007Token()
        loginWithPwd()
    }
    @IBAction func logoutAction(_ sender: Any) {
        EMClient.shared().logout(false) { [weak self] aError in
            if let error = aError {
                EMClient.shared().logout(false)
                self?.printLog("logout error: \(error)")
            } else {
                self?.printLog("logout success")
            }
        }
    }
    @IBAction func sendAction(_ sender: Any) {
//        EMClient.shared().roomManager?.getChatroomsFromServer(withPage: 0, pageSize: 10, completion: { [weak self] result, e in
//            if let list = result?.list {
//                EMClient.shared().roomManager?.joinChatroom(list.first?.chatroomId ?? "",ext: "kuoz", leaveOtherRooms: true, completion: { rm, e in
//                    if e == nil {
//                        self?.printLog("joinChatroom:\(rm?.chatroomId ?? "") ext:kuoz")
//                    }
//                })
//            }
//        })
//        return
        if let text = self.textField.text {
//            for _ in 0...1000 {
//                text = text.appending("hello world")
//            }
            let body = EMTextMessageBody(text: "hello")
            //body.targetLanguages = ["en","ja","de"]
            let msg = EMChatMessage(conversationID: self.groupId, body: body, ext:["intValue":32,"boolValue":true,"doubleValue":3.14,"uintValue":UInt32(32),"int64Value":Int64(32),"stringValue":"oldString","jsonStringValue":["childKey": "childValue"]])
            msg.chatType = .groupChat
                EMClient.shared().chatManager?.send(msg, progress: nil, completion: { msg, err in
                    if err == nil {
                        self.messageId = msg?.messageId ?? ""
                        self.printLog("send message success")
                    } else {
                        self.printLog("send message err")
                    }
                    
                })
            
        }
    }
    
    func fetchHistoryMessage(conversationId: String,cursor: String) {
        
//        EMClient.shared().chatManager?.asyncFetchHistoryMessages(fromServer: conversationId, conversationType: .chat, startMessageId: cursor, fetch: .up, pageSize: 5, completion: { [weak self] result, err in
//            self?.messageCount += result?.list?.count ?? 0
//            if let list = result?.list {
//                for msg in list {
//                    self?.printLog("cursor:\(cursor), messageId:\(msg.messageId)")
//                }
//            }
//            if let cursor = result?.cursor,result?.list?.count == 5 {
//                self?.fetchHistoryMessage(conversationId: conversationId, cursor: cursor)
//            }
//            self?.printLog("messageCount:\(self?.messageCount ?? 0)")
//        })
    }
    
    @IBAction func sendFileAction(_ sender: Any) {
        let msgBody = EMCombineMessageBody(title: "dd", summary: "dads", compatibleText: "asdf", messageIdList: [])
        EMClient.shared().chatManager?.send(EMChatMessage(conversationID: "lxm2", body: msgBody, ext: nil), progress: nil)
 //       sendFileMessage()
//        EMClient.shared().chatManager?.asyncFetchHistoryMessages(fromServer: "lxm", conversationType: .chat, startMessageId: "", pageSize: 100, completion: { result, err in
//            self.printLog("asyncFetchHistoryMessages:\(result?.list?.count ?? 0)")
//        })
//        generateData()
 //       self.sendFileMessage()
//        if let imageFile = Bundle.main.path(forResource: "IMG_8791", ofType: "HEIC") {
//            let imageBody = EMImageMessageBody(localPath: imageFile, displayName: "IMG_8791.heic")
//            let msg = EMChatMessage(conversationID: self.conversationIdField.text ?? "", body: imageBody, ext: nil)
//            EMClient.shared().chatManager?.send(msg, progress: nil, completion: { msg, e in
//
//            })
//        }
    }
    
    func testPin() {
        
//        EMClient.shared().chatManager?.getPinnedMessages(fromServer: "241486095515649", completion: { msgs, err in
//            if let msgs = msgs {
//                for msg in msgs {
//                    self.printLog("pinned messageId:\(msg.messageId) pinnedBy:\(msg.pinnedInfo?.operatorId ?? "") at:\(msg.pinnedInfo?.pinTime ?? 0)")
//                }
//            }
//        })
    }
    
//    func testFilterConversations() {
//        if let conversations = EMClient.shared().chatManager?.filterConversations({ conversation in
//            if conversation.type == .chat {
//                return true
//            }
//            return false
//        }, clearBuffer: true) {
//            for conversation in conversations {
//                printLog("1 conversationId:\(conversation.conversationId ?? "")")
//            }
//        }
//
//        if let conversations = EMClient.shared().chatManager?.filterConversations({ conversation in
//            if conversation.type == .chat {
//                return false
//            }
//            return true
//        }, clearBuffer: true) {
//            for conversation in conversations {
//                printLog("2 conversationId:\(conversation.conversationId ?? "")")
//            }
//        }
//    }
    
    func generateData() {
        printLog("generateData begin")
        for i in 0...2000 {
            let conversationId = "lxm\(i)"
            if let conversation = EMClient.shared().chatManager?.getConversation(conversationId, type: .chat, createIfNotExist: true) {
                var messages: [EMChatMessage] = []
                for j in 0...20 {
                    let str = msgStrings[j % 11]
                    let message = EMChatMessage(conversationID: conversationId, body: EMTextMessageBody(text: str), ext: ["nickName": "蓝色天空", "avatar": "https://downloadsdk.easemob.com/downloads/IMDemo/liveLogo.png", "role": 1, "country": "China"])
                    messages.append(message)
                }
                EMClient.shared().chatManager?.import(messages)
                let latestReceiveMsg = EMChatMessage(conversationID: conversationId,from: conversationId,to: EMClient.shared().currentUsername ?? "", body: EMTextMessageBody(text: "latestReceive"), ext: ["nickName": "蓝色天空", "avatar": "https://downloadsdk.easemob.com/downloads/IMDemo/liveLogo.png", "role": 1, "country": "China"])
                latestReceiveMsg.direction = .receive
                latestReceiveMsg.isRead = false
                conversation.append(latestReceiveMsg, error: nil)
                let latestMsg = EMChatMessage(conversationID: conversationId, body: EMTextMessageBody(text: "latestSend"), ext: nil)
                conversation.append(latestMsg, error: nil)
                
                printLog("generateData import \(conversationId),latestMsgId:\(conversation.latestMessage?.messageId ?? ""),latestReceiveMessageId:\(conversation.lastReceivedMessage()?.messageId ?? "")")
            }

        }
        printLog("generateData end")
    }
    
    func modifyVideoMessage() {
        if let msg = EMClient.shared().chatManager?.getMessageWithMessageId("1384637766834325460") {
            let body = msg.body as! EMVideoMessageBody
            print("image msg.localPath:\(body.localPath ?? ""),thumbnailLocalPath:\(body.thumbnailLocalPath ?? "")")
            EMClient.shared.chatManager?.modifyMessage("1384637766834325460", body: EMVideoMessageBody(localPath: "dafasdf", displayName: "dddd"), completion: { e, msg in
                
            })
        }
    }
    
    func modifyCombineMessage() {
//        if let msg = EMClient.shared().chatManager?.getMessageWithMessageId("1384985791192631252") {
//            let body = msg.body as! EMCombineMessageBody
//            print("combine msg.title:\(body.title ?? ""),summary:\(body.summary ?? "")")
//            EMClient.shared.chatManager?.modifyMessage("1384985791192631252", body: EMCombineMessageBody(title: "ddd", summary: "su", compatibleText: "dddd", messageIdList: []), ext: ["newExtKey": "newExtValue"], completion: { e, msg in
//
//            })
//        }
    }
    
    func modifyImageMessage() {
//        if let msg = EMClient.shared().chatManager?.getMessageWithMessageId("1384637197696632788") {
//            let body = msg.body as! EMImageMessageBody
//            print("image msg.localPath:\(body.localPath ?? ""),thumbnailLocalPath:\(body.thumbnailLocalPath ?? "")")
//            EMClient.shared.chatManager?.modifyMessage("1384637197696632788", body: EMImageMessageBody(localPath: "dafasdf", displayName: "dddd"), ext: ["newExtKey": "newExtValue"], completion: { e, msg in
//
//            })
//        }
    }
    
    func modifyVoiceMessage() {
//        if let msg = EMClient.shared().chatManager?.getMessageWithMessageId("1384984734886528980") {
//            let body = msg.body as! EMVoiceMessageBody
//            print("voice msg.localPath:\(body.localPath ?? "")")
//            EMClient.shared.chatManager?.modifyMessage("1384984734886528980", body: EMVoiceMessageBody(localPath: "voice path", displayName: "voice"), ext: ["newVoiceExtKey": [4,3,21]], completion: { e, msg in
//
//            })
//        }
    }
    
    func logConversations() {
        if let conversations = EMClient.shared().chatManager?.getAllConversations() {
            for conversation in conversations {
                printLog("conversation:\(conversation.conversationId ?? ""),unread:\(conversation.unreadMessagesCount),messageCount:\(conversation.messagesCount),latestmsgId:\(conversation.latestMessage?.messageId ?? ""),latestReceiveMsgId:\(conversation.lastReceivedMessage()?.messageId ?? "")")
            }
        }
    }
    
    func fetchHistoryMessages(cursor: String?) {
        EMClient.shared().chatManager?.fetchMessagesFromServer(by: self.conversationIdField.text ?? "", conversationType: .chat, cursor: cursor, pageSize: 6, option: nil, completion: { result, e in
            self.printLog("cursor:\(result?.cursor ?? ""),result:\(result?.list?.count ?? 0)")
            if let nextCursor = result?.cursor,nextCursor.isEmpty == false {
                self.fetchHistoryMessages(cursor: nextCursor)
            }
        })
    }
    
    func mockTask(urlString: String, index: Int = 0) {
        guard let url = URL(string: urlString) else {
            printLog("Invalid URL: \(urlString)")
            return
        }
        
        DispatchQueue.global().async {
            let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                if let error = error {
                    self?.printLog("Task \(index) failed: \(error.localizedDescription)")
                    return
                }
                
                if let data = data {
                    self?.printLog("Task \(index) succeeded, downloaded \(data.count) bytes")
                } else {
                    self?.printLog("Task \(index) failed: No data received")
                }
            }
            task.resume()
        }
    }
    
    func testTask(startIndex: Int = 0) {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            if startIndex >= 2000 {
                self.printLog("testTask end")
                return
            }
            let pageCount = 20
            for i in startIndex...startIndex+pageCount-1 {
                let conversationId = "lxm\(i)"
                if let conversation = EMClient.shared().chatManager?.getConversation(conversationId, type: .chat, createIfNotExist: true) {
                    // 先设置所有消息已读
                    var err: EMError? = nil
                    conversation.markAllMessages(asRead: &err)
                    
                    // 然后插入消息
                    let body = EMTextMessageBody(text: "hello")
                    let msg = EMChatMessage(conversationID: conversationId,from: conversationId,to: EMClient.shared().currentUsername ?? "", body: body, ext: ["nickName": "蓝色天空", "avatar": "https://downloadsdk.easemob.com/downloads/IMDemo/liveLogo.png", "role": 1, "country": "China"])
                    msg.isRead = false
                    msg.direction = .receive
                    conversation.insert(msg, error: nil)
                    
                }
            }
            self.testTask(startIndex: startIndex + pageCount)
        }
    }
    
    @IBAction func testAction(_ sender: Any) {
        for i in 0...10 {
            mockTask(urlString: "https://downloadsdk.easemob.com/downloads/IMDemo/native.zip",index: i)
        }
        //generateData();
        testTask()
//        if let conversation = EMClient.shared().chatManager?.getConversationWithConvId(self.groupId) {
//            conversation.loadMessages(withKeyword: nil, timestamp: -1, count: 20, fromUsers: ["lxm","lxm2"], searchDirection: .up, scope: .all) { msgs, e in
//                if let msgs = msgs {
//                    for msg in msgs {
//                        self.printLog("messageId:\(msg.messageId),isReadAck:\(msg.isReadAcked),isDeliverAck:\(msg.isDeliverAcked),isRead:\(msg.isRead)")
//                    }
//                }
//            }
//        }
//        let option = EMFetchServerMessagesOption()
//        option.isSave = true
//        option.fromIds = ["lxm","lxm2"]
//        EMClient.shared().chatManager?.fetchMessagesFromServer(by: self.groupId, conversationType: .groupChat, cursor: "", pageSize: 10, option: option, completion: { result, e in
//            if let list = result?.list {
//                for msg in list {
//                    self.printLog("message:\(msg.messageId),isReadAck:\(msg.isReadAcked),isDeliverAck:\(msg.isDeliverAcked),isRead:\(msg.isRead)")
//                }
//            }
//        })
        //fetchHistoryMessages(cursor: "")
//        if let conv = EMClient.shared.chatManager?.getConversationWithConvId(self.conversationIdField.text ?? "") {
//            if conv.latestMessage != nil {
//                conv.deleteMessage(withId: conv.latestMessage.messageId, error: nil)
//                logConversations()
//                return
//            }
//        }
//        logConversations()
//        EMClient.shared().chatManager?.deleteMessages(before: UInt(Date().timeIntervalSince1970 * 1000 - 10000)) {
//            e in
//            print("deleteMessages")
//            self.logConversations()
//        }

//        EMClient.shared().chatManager?.deleteConversation(self.conversationIdField.text ?? "", isDeleteMessages: false) {_,_ in
//
//        }
        
        
//        EMClient.shared.chatManager?.getConversationsFromServer(withCursor: "", pageSize: 20, completion: { result, e in
//            if let conv = EMClient.shared.chatManager?.getConversation(self.conversationIdField.text ?? "", type: .chat, createIfNotExist: true) {
//                if conv.latestMessage.body.type == .text {
//                    if let textBody = conv.latestMessage.body as? EMTextMessageBody {
//                        self.printLog("textBody.text:\(textBody.text),targetLanguage:\(textBody.targetLanguages ?? []),translations:\(textBody.translations ?? [:])")
//                    }
//                    if let reactions = conv.latestMessage.reactionList {
//                        for reaction in reactions {
//                            self.printLog("reaction.emoji:\(reaction.reaction  ),reaction.count:\(reaction.count),userList:\(reaction.userList ?? [])")
//                        }
//                    }
//                }
//            }
//        })
//        let option = EMFetchServerMessagesOption()
//        option.isSave = true
//        EMClient.shared().chatManager?.fetchMessagesFromServer(by: self.conversationIdField.text ?? "", conversationType: .chat, cursor: "", pageSize: 20, option: option) {_,_ in
//            if let conv = EMClient.shared.chatManager?.getConversation("lxm2", type: .chat, createIfNotExist: true) {
//                //conv.deleteAllMessages(nil)
//                self.printLog("conversation:\(conv.conversationId ?? ""),messageCount;\(conv.messagesCount)")
//            }
//        }
//        if let conv = EMClient.shared.chatManager?.getConversation("lxm2", type: .chat, createIfNotExist: true) {
//            EMClient.shared().chatManager?.removeMessagesFromServer(with: conv, timeStamp: TimeInterval(Int((Date().timeIntervalSince1970 - 30) * 1000)) ) {_ in
//                self.printLog("conversation:\(conv.conversationId ?? ""),messageCount;\(conv.messagesCount)")
//            }
//            //conv.removeMessagesStart(0, to: Int((Date().timeIntervalSince1970 - 30) * 1000))
//
//        }
        
        
//        EMClient.shared().roomManager?.getChatroomsFromServer(withPage: 0, pageSize: 20, completion: { result, e in
//            if let rooms = result?.list {
//                for room in rooms {
//                    print("room id:\(room.chatroomId ?? "")")
//                    EMClient.shared().roomManager?.joinChatroom(room.chatroomId ?? "") {
//                        _,_ in
//                    }
//                }
//            }
//        })
//        EMClient.shared().contactManager?.getContactsFromServer(completion: { userIds, e in
//            if let userIds = userIds {
//                print("contacts count:\(userIds.count)")
//            } else {
//                print("get contacts failed")
//            }
//        })
        
//        modifyImageMessage()
//        //modifyVoiceMessage()
//        modifyCombineMessage()
//        modifyVideoMessage()

        

//        let keyword = "无地2"
//        let ts0 = Date().timeIntervalSince1970*1000
//        let ret1 = EMClient.shared().chatManager?.loadMessages(withKeyword: "人杰qlkd", timestamp: -1, count: 1000, fromUser: "", searchDirection: .up)
//        let ts1 = Date().timeIntervalSince1970*1000
//        print("testAction global no scope:\(ts1-ts0),result:\(ret1?.count ?? 0)")
//        let ret2 = EMClient.shared().chatManager?.loadMessages(withKeyword: "人杰asdf", timestamp: -1, count: 1000, fromUser: "", searchDirection: .up, scope: .content)
//        let ts2 = Date().timeIntervalSince1970*1000
//        print("testAction global scope:\(ts2-ts1),result:\(ret2?.count ?? 0)")
//        var sum1 = 0
//        if let conversations = EMClient.shared().chatManager?.getAllConversations() {
//            for conversation in conversations {
//                let ret = conversation.loadMessages(withKeyword: keyword, timestamp: -1, count: 1000, fromUser: "", searchDirection: .up)
//                sum1 = sum1 + (ret?.count ?? 0)
//            }
//        }
//        let ts3 = Date().timeIntervalSince1970*1000
//        print("testAction no scope:\(ts3-ts2),result:\(sum1)")
//        var sum2 = 0;
//        if let conversations = EMClient.shared().chatManager?.getAllConversations() {
//            for conversation in conversations {
//                let ret = conversation.loadMessages(withKeyword: keyword, timestamp: -1, count: 1000, fromUser: "", searchDirection: .up, scope: .content)
//                sum2 = sum2 + (ret?.count ?? 0)
//            }
//        }
//        let ts4 = Date().timeIntervalSince1970*1000
//        print("testAction has scope:\(ts4-ts3),result:\(sum2)")
        
        
       // EMClient.shared().changeAppId("2e597744c44e4eed9b7c7c64e2ba2874")
//        self.loginWithPwd()
//        EMClient.shared().roomManager?.joinChatroom("262965207040001") {
//            room, e in
//            if e == nil {
//                self.chatroomId = room?.chatroomId ?? ""
//                self.printLog("join chatroom:\(room?.chatroomId ?? "") success,memberCount:\(room?.occupantsCount ?? 0)")
//                EMClient.shared.roomManager?.getChatroomMuteListFromServer(withId: "262965207040001", pageNumber: 0, pageSize: 20, completion: { userIds, e in
////                    room?.muteMembers?.forEach({ (key: String, value: NSNumber) in
////                        self.printLog("muted user:\(key),expire:\(value)")
////                    })
//                })
//            }
//        }
        
//        EMClient.shared().groupManager?.getJoinedGroupsFromServer(withPage: 0, pageSize: 20, needMemberCount: false, needRole: false, completion: { groups, err in
//            if let groups = groups,!groups.isEmpty {
//                let group = groups[0]
//                EMClient.shared().groupManager?.getGroupFileList(withId: group.groupId, pageNumber: 0, pageSize: 20, completion: { groupSharedFiles, e in
//                    if let groupSharedFiles = groupSharedFiles {
//                        for groupSharedFile in groupSharedFiles {
//                            self.printLog("groupSharedFile:\(groupSharedFile.fileName)")
//                        }
//                    }
//                })
//            }
//        })
//        if let conversation = EMClient.shared().chatManager?.getConversationWithConvId(self.conversationIdField.text ?? "") {
//            self.printLog("conversation:\(conversation.conversationId ?? ""),unread:\(conversation.unreadMessagesCount)")
//            conversation.loadMessagesStart(fromId: "", count: 20, searchDirection: .up) { [weak self] list, e in
//                if let list = list {
//                    for msg in list {
//                        self?.printLog("message:\(msg.messageId),isReadAck:\(msg.isReadAcked),isDeliverAck:\(msg.isDeliverAcked),isRead:\(msg.isRead)")
//                    }
//                }
//            }
//        }
//        EMClient.shared().chatManager?.asyncFetchHistoryMessages(fromServer: self.conversationIdField.text ?? "", conversationType: .chat, startMessageId: "", fetch: .up, pageSize: 20) {
//            [weak self] result, e in
//               if let list = result?.list {
//                   for msg in list {
//                       self?.printLog("message:\(msg.messageId),isReadAck:\(msg.isReadAcked),isDeliverAck:\(msg.isDeliverAcked),isRead:\(msg.isRead)")
//                   }
//               }
//        }
//        let option = EMFetchServerMessagesOption()
//        option.isSave = true
//        EMClient.shared().chatManager?.fetchMessagesFromServer(by: self.conversationIdField.text ?? "", conversationType: .chat, cursor: "", pageSize: 10, option: option, completion: { [weak self] result, e in
//            if let list = result?.list {
//                for msg in list {
//                    if msg.body.type == .file {
//                        let localPath = (msg.body as? EMFileMessageBody)?.localPath
//                        if FileManager.default.fileExists(atPath: localPath ?? "") {
//                            self?.printLog("message localPath exist")
//                        } else {
//                            self?.printLog("message localPath not exist")
//                        }
//                    }
//                    self?.printLog("message:\(msg.messageId),isReadAck:\(msg.isReadAcked),isDeliverAck:\(msg.isDeliverAcked),isRead:\(msg.isRead)")
//                }
//            }
//        })
//        EMClient.shared().roomManager?.joinChatroom("268846180139015", completion: { [weak self] rm, e in
//            if e == nil,let rm = rm {
//                self?.printLog("joinChatroom:\(rm.chatroomId ?? "") success,createAt:\(rm.createTimestamp),allMute:\(rm.isMuteAllMembers),memberCount:\(rm.occupantsCount),isInWhitelist:\(rm.isInWhitelist),muteTimestamp:\(rm.muteExpireTimestamp)")
//            }
//
//        })
        
    }
    
    // Outputs running log
    func printLog(_ log: Any...) {
        print(log)
        DispatchQueue.main.async {
            self.logView.text.append(
                DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                + ":  " + String(reflecting: log) + "\r\n"
            )
            self.logView.scrollRangeToVisible(NSRange(location: self.logView.text.count, length: 1))
        }
    }
}

extension ViewController: EMLogDelegate {
    func logDidOutput(_ log: String) {
        
    }
}

extension ViewController {
    func initSDK() {
//        func getOptions() -> EMOptions {
//            if useAppId {
//                let tmp = EMOptions(appId: "3f7718b6a2eb45e5b3bc82ee6fee3504")
//                return tmp
//            } else {
//                return EMOptions(appkey: Appkey)
//            }
//        }
        //let options = getOptions()
         let options = EMOptions(appkey: Appkey)
        //options.autoLoadAllConversations = false
        options.enableConsoleLog = true
        options.enableRequireReadAck = true
        options.loadEmptyConversations = true
        //options.autoLoadConversations = true
        options.isAutoLogin = true
        options.enableRequireReadAck = true
        options.enableDeliveryAck = true
        //options.enableCrashReport = true
        //options.includeSendMessageInMessageListener = false
        //options.useReplacedMessageContents = true
        options.apnsCertName = "EaseIM_APNS_Developer"
        //options.workPathCopiable = true
        if useSandbox {
            useSpecialServer(options)
        }
        
        EMClient.shared().initializeSDK(with: options)
        DispatchQueue.main.async {
            if let conversation1 = EMClient.shared().chatManager?.getConversation("lxm2", type: .chat, createIfNotExist: true) {
                let _ = conversation1.latestMessage
                let _ = conversation1.unreadMessagesCount
                let _ = conversation1.messagesCount
            }
            
        }
        EMClient.shared().add(self, delegateQueue: nil)
        EMClient.shared().chatManager?.add(self, delegateQueue: nil)
//        EMClient.shared().addMultiDevices(delegate: self, queue: nil)
        EMClient.shared().groupManager?.add(self, delegateQueue: nil)
        EMClient.shared().roomManager?.add(self, delegateQueue: nil)
        //EMClient.shared.addLog(delegate: self, queue: nil)
    }
    
    func useSpecialServer(_ options: EMOptions) {
        // 必须将enableDnsConfig设置为false
        options.setValue(false, forKey: "enableDnsConfig")
        // 设置IM长连接服务器
        options.setValue("180.184.143.60", forKey: "chatServer")
        options.setValue(6717, forKey: "chatPort")
        // 设置IM Rest服务器
        options.setValue("https://a1-hsb.easemob.com", forKey: "restServer")
        // 连接TLS的IM长连接服务器，需要设置enableTLSConnection为true；否则，不需要单独设置enableTLSConnection
        //options.setValue(false, forKey: "enableTLSConnection")
    }
    
    func loginWith007Token() {
        
        if let userId = userIdField.text {
            let appId = "3f7718b6a2eb45e5b3bc82ee6fee3504"
            let cert = "02d09b6c08fb4988a789465ac48a66c9"
            let token = TokenBuilder.buildToken(withAppId: appId, cert: cert, userId: userId, expiredTime: 3600)
            EMClient.shared().login(withUsername: userId, token: token) { [weak self] (aUsername, aError) in
                if let error = aError {
                    self?.printLog("login error: \(error.errorDescription ?? "")")
                } else {
                    self?.printLog("login success")
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    func addLog() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.005) {
            EMClient.shared().log("1902387409128375098237450928374509823740589723409857190238740912837509823745092837450982374058972340985719023874091283750982374509283745098237405897234098571902387409128375098237450928374509823740589723409857190238740912837509823745092837450982374058972340985719023874091283750982374509283745098237405897234098571902387409128375098237450928374509823740589723409857")
            self.addLog();
        }
    }
}

//extension ViewController: EMMultiDevicesDelegate {
//    func multiDevicesConversationEvent(_ event: EMMultiDevicesEvent, conversationId: String, conversationType: EMConversationType) {
//        self.printLog("multiDevicesConversationEvent:\(event),conversationId:\(conversationId)")
//    }
//

extension ViewController: EMChatroomManagerDelegate {
    
//    func chatroomMuteListDidUpdate(_ aChatroom: EMChatroom, addedMutedMembers aMutes: [String], muteExpire aMuteExpireAt: Int) {
//        self.printLog("joinChatroom:\(aChatroom.chatroomId ?? "") success,createAt:\(aChatroom.createTimestamp),allMute:\(aChatroom.isMuteAllMembers),memberCount:\(aChatroom.occupantsCount),isInWhitelist:\(aChatroom.isInWhitelist),muteTimestamp:\(aChatroom.muteExpireTimestamp)")
//    }
//
//    func chatroomMuteListDidUpdate(_ aChatroom: EMChatroom, addedMutedMembers aMutes: [String : NSNumber]) {
//        self.printLog("joinChatroom:\(aChatroom.chatroomId ?? "") success,createAt:\(aChatroom.createTimestamp),allMute:\(aChatroom.isMuteAllMembers),memberCount:\(aChatroom.occupantsCount),isInWhitelist:\(aChatroom.isInWhitelist),muteTimestamp:\(aChatroom.muteExpireTimestamp)")
//
//    }
//
//    func chatroomMuteListDidUpdate(_ aChatroom: EMChatroom, removedMutedMembers aMutes: [String]) {
//        self.printLog("joinChatroom:\(aChatroom.chatroomId ?? "") success,createAt:\(aChatroom.createTimestamp),allMute:\(aChatroom.isMuteAllMembers),memberCount:\(aChatroom.occupantsCount),isInWhitelist:\(aChatroom.isInWhitelist),muteTimestamp:\(aChatroom.muteExpireTimestamp)")
//    }
//
//    func chatroomWhiteListDidUpdate(_ aChatroom: EMChatroom, addedWhiteListMembers aMembers: [String]) {
//        self.printLog("joinChatroom:\(aChatroom.chatroomId ?? "") success,createAt:\(aChatroom.createTimestamp),allMute:\(aChatroom.isMuteAllMembers),memberCount:\(aChatroom.occupantsCount),isInWhitelist:\(aChatroom.isInWhitelist),muteTimestamp:\(aChatroom.muteExpireTimestamp)")
//    }
//
//    func chatroomWhiteListDidUpdate(_ aChatroom: EMChatroom, removedWhiteListMembers aMembers: [String]) {
//        self.printLog("joinChatroom:\(aChatroom.chatroomId ?? "") success,createAt:\(aChatroom.createTimestamp),allMute:\(aChatroom.isMuteAllMembers),memberCount:\(aChatroom.occupantsCount),isInWhitelist:\(aChatroom.isInWhitelist),muteTimestamp:\(aChatroom.muteExpireTimestamp)")
//    }
//
//    func chatroomAllMemberMuteChanged(_ aChatroom: EMChatroom, isAllMemberMuted aMuted: Bool) {
//        self.printLog("joinChatroom:\(aChatroom.chatroomId ?? "") success,createAt:\(aChatroom.createTimestamp),allMute:\(aChatroom.isMuteAllMembers),memberCount:\(aChatroom.occupantsCount),isInWhitelist:\(aChatroom.isInWhitelist),muteTimestamp:\(aChatroom.muteExpireTimestamp)")
//    }
//
//    func chatroomAdminListDidUpdate(_ aChatroom: EMChatroom, addedAdmin aAdmin: String) {
//        self.printLog("joinChatroom:\(aChatroom.chatroomId ?? "") success,createAt:\(aChatroom.createTimestamp),allMute:\(aChatroom.isMuteAllMembers),memberCount:\(aChatroom.occupantsCount),isInWhitelist:\(aChatroom.isInWhitelist),muteTimestamp:\(aChatroom.muteExpireTimestamp)")
//    }
//
//    func chatroomAdminListDidUpdate(_ aChatroom: EMChatroom, removedAdmin aAdmin: String) {
//        self.printLog("joinChatroom:\(aChatroom.chatroomId ?? "") success,createAt:\(aChatroom.createTimestamp),allMute:\(aChatroom.isMuteAllMembers),memberCount:\(aChatroom.occupantsCount),isInWhitelist:\(aChatroom.isInWhitelist),muteTimestamp:\(aChatroom.muteExpireTimestamp)")
//    }
}

extension ViewController: EMChatManagerDelegate {
    
    func conversationListDidUpdate(_ aConversationList: [EMConversation]) {
//        if let conversations = EMClient.shared().chatManager?.getAllConversations() {
//            self.printLog("conversationListDidUpdate conversationscount:\(conversations.count)")
//        }
    }
    func messagesDidReceive(_ aMessages: [EMChatMessage]) {
        
        for msg in aMessages {
            if msg.body.type == .image {
                let formateMessage = EMChatMessage(conversationID: "lxm3", body: msg.body, ext: nil)
                EMClient.shared().chatManager?.send(formateMessage, progress: nil) {
                    _,_ in
                }
            }
        }
                
    }
    
    func cmdMessagesDidReceive(_ aCmdMessages: [EMChatMessage]) {
        if let msg = aCmdMessages.first,
            let conv = EMClient.shared().chatManager?.getConversationWithConvId(msg.conversationId) {
               self.printLog("conv:\(conv.conversationId ?? ""),messageCount:\(conv.messagesCount)");
           }
    }
    
    func onMessageContentChanged(_ message: EMChatMessage, operatorId: String, operationTime: UInt) {
        switch message.swiftBody {
        case .text(content: let content):
            printLog("onMessageContentChanged text:\(content),ext:\(message.ext)")
        case .image(localPath: let localPath, displayName: let displayName):
            printLog("onMessageContentChanged image localPath:\(localPath),displayName:\(displayName),ext:\(message.ext)")
        case .video(localPath: let localPath, displayName: let displayName):
            printLog("onMessageContentChanged video localPath:\(localPath),displayName:\(displayName),ext:\(message.ext)")
        case .location(latitude: let latitude, longitude: let longitude, address: let address, buildingName: let buildingName):
            printLog("onMessageContentChanged location latitude:\(latitude),longitude:\(longitude),address:\(address),buildingName:\(buildingName),ext:\(message.ext)")
        case .voice(localPath: let localPath, displayName: let displayName):
            printLog("onMessageContentChanged voice localPath:\(localPath),displayName:\(displayName),ext:\(message.ext)")
        case .file(localPath: let localPath, displayName: let displayName):
            printLog("onMessageContentChanged file localPath:\(localPath),displayName:\(displayName),ext:\(message.ext)")
        case .custom(event: let event, customExt: let customExt):
            printLog("onMessageContentChanged custom event:\(event),customExt:\(customExt),ext:\(message.ext)")
        case .combine(title: let title, summary: let summary, compatibleText: let compatibleText, messageIdList: let messageIdList):
            printLog("onMessageContentChanged combine title:\(title),summary:\(summary),compatibleText:\(compatibleText),ext:\(message.ext)")
        @unknown default:
            break
        }
    }
    
//    func onMessagePinChanged(_ messageId: String, conversationId: String, operation pinOperation: EMMessagePinOperation, pinInfo: EMMessagePinInfo) {
//
//    }
//
    func messagesInfoDidRecall(_ aRecallMessagesInfo: [EMRecallMessageInfo]) {
        
    }
    
    func onConversationRead(_ from: String, to: String) {
        let conversationId = from == EMClient.shared().currentUsername ? to : from
        if let conversation = EMClient.shared().chatManager?.getConversationWithConvId(conversationId) {
            printLog("onConversationRead conversationId:\(conversationId), unread:\(conversation.unreadMessagesCount)")
        }
    }
}

//extension ViewController: EMGroupManagerDelegate {
//    func groupAllMemberMuteChanged(_ aGroup: EMGroup, isAllMemberMuted aMuted: Bool) {
//        self.printLog("groupId:\(aGroup.groupId),allMute:\(aMuted)")
//    }
//}

extension ViewController: UIDocumentPickerDelegate {
    func sendFileMessage() {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.content", "public.text", "public.source-code", "public.image", "public.jpeg", "public.png", "com.adobe.pdf", "com.apple.keynote.key", "com.microsoft.word.doc", "com.microsoft.excel.xls", "com.microsoft.powerpoint.ppt","public.data","public.heic"], in: .open)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .fullScreen
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if controller.documentPickerMode == UIDocumentPickerMode.open {
            guard let selectedFileURL = urls.first else {
                return
            }
            if selectedFileURL.startAccessingSecurityScopedResource() {
//                 if let data = FileManager.default.contents(atPath: selectedFileURL.path) {
//                    let filePath = TokenBuilder._uploadFileData(data, fileName: selectedFileURL.lastPathComponent)
//                    EMClient.shared().groupManager?.getJoinedGroupsFromServer(withPage: 0, pageSize: 20, needMemberCount: false, needRole: false, completion: { groups, err in
//                        if let groups = groups,!groups.isEmpty {
//                            let group = groups[0]
//                            EMClient.shared().groupManager?.uploadGroupSharedFile(withId: group.groupId, filePath: filePath, progress: nil, completion: { file, err in
//
//                                let filename = file?.fileName
//                                self.printLog("filename:\(filename ?? "")")
//                            })
//                        }
//                    })
//                }

                //print("token:\(EMClient.shared().accessUserToken)")
                //if let data = FileManager.default.contents(atPath: selectedFileURL.path) {
                    //let ret = FileManager.default.createFile(atPath: FileManager.default.temporaryDirectory.path + "/tmp", contents: data)
                    let fileMessageBody = EMFileMessageBody(localPath: "", displayName: selectedFileURL.lastPathComponent)
                    //fileMessageBody?.isGif = true
                    let msg = EMChatMessage(conversationID: self.conversationIdField.text ?? "", body: fileMessageBody, ext: ["originExtKey":"originExtValue"])
                    EMClient.shared().chatManager?.send(msg, progress: nil) {
                        [weak self] msg, err in
                        if let error = err {
                            self?.printLog("send file message error: \(error.errorDescription ?? "")")
                        } else {
                            self?.messageId = msg?.messageId ?? ""
                            self?.printLog("send file message success")
//                            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
//                                EMClient.shared().chatManager?.modifyMessage(msg?.messageId ?? "", body: EMFileMessageBody(localPath: "da", displayName: "asdfasdf"), completion: { e, m in
//                                    if let m = m {
//                                        print("edit success.content:\(m.swiftBody) ext:\(m.ext)")
//                                    }
//                                })
//                            }
                            
                        }
                   // }
                }
                selectedFileURL.stopAccessingSecurityScopedResource()
            } else {
                printLog("permission disable")
            }
        }
    }
    
    func filePath() -> String {
        var path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        path = (path as NSString).appendingPathComponent("appdata/chatbuffer/")
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }

        return path
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        
    }
}

extension ViewController: UIImagePickerControllerDelegate
{
    func sendImageMessage() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        imagePicker.modalPresentationStyle = .fullScreen
        self.present(imagePicker, animated: true, completion: nil)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage,
           let data = image.jpegData(compressionQuality: 1.0) {
            let imageData = EMImageMessageBody(data: data, displayName: "IMG_8791.jpg")
            let msg = EMChatMessage(conversationID: "lxm", body: imageData, ext: nil)
            EMClient.shared().chatManager?.send(msg, progress: nil) {
                [weak self] msg, err in
                if let error = err {
                    self?.printLog("send image message error: \(error.errorDescription ?? "")")
                } else {
                    self?.printLog("send image message success")
                }
            }
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

extension EMConversation {
    func toString() -> String {
        return ""
        //return "conversationId:\(self.conversationId ?? "");type:\(self.type);unreadCount:\(self.unreadMessagesCount);messageCount:\(messagesCount);ext:\(ext);latestMessage:\(self.latestMessage?.messageId ?? "");lastReceivedMessage:\(self.lastReceivedMessage()?.messageId ?? "");isThread:\(self.isChatThread);isPinned:\(self.isPinned);pinnedTime:\(pinnedTime);marks:\(marks);disturbType:\(disturbType)"
    }
}

extension ViewController: EMClientDelegate {
    func onOfflineMessageSyncStart() {
        self.printLog("EMClientDelegate:onOfflineMessageSyncStart")
    }
    
    func onOfflineMessageSyncFinish() {
        self.printLog("EMClientDelegate:onOfflineMessageSyncFinish")
    }
    
    func connectionStateDidChange(_ aConnectionState: EMConnectionState) {
        self.printLog("EMClientDelegate: aConnectionState:\(aConnectionState)")
    }
    
    func tokenDidExpire(_ aErrorCode: EMErrorCode) {
        loginWith007Token()
    }
    
    // 用户账户已经被移除
    func userAccountDidRemoveFromServer() {
        
    }
    
//    // 用户已经在其他设备登录
//    func userAccountDidLoginFromOtherDevice(with info: EMLoginExtensionInfo?) {
//
//    }
    
    // 用户账户被禁用
    func userDidForbidByServer() {
        
    }
    
    // 当前账号被强制退出登录，有以下原因：密码被修改；登录设备数过多；服务被封禁; 被强制下线;
    func userAccountDidForced(toLogout aError: EMError?) {
        EMClient.shared.logout(false)
    }
    
    func autoLoginDidCompleteWithError(_ aError: EMError?) {
        
    }
}

extension ViewController: EMGroupManagerDelegate {
    func userDidJoin(_ group: EMGroup, users userIds: [String]) {
        print("groupId:\(group.groupId ?? ""),join:\(userIds)")
    }
    
    func userDidJoin(_ aGroup: EMGroup, user aUsername: String) {
        print("groupId:\(aGroup.groupId ?? ""),join:\(aUsername)")
    }
    
    func userDidLeave(_ group: EMGroup, users userIds: [String]) {
        print("groupId:\(group.groupId ?? ""),leave:\(userIds)")
    }
    
    func userDidLeave(_ aGroup: EMGroup, user aUsername: String) {
        print("groupId:\(aGroup.groupId ?? ""),leave:\(aUsername)")
    }
}


