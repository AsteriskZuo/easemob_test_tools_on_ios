//
//  test_remove_group_member.swift
//  sdkTest
//
//  Created on 2023.
//

import UIKit
import HyphenateChat

class test_remove_group_member {
    
    weak var viewController: ViewController?
    
    // Static array to store received message IDs
    static var receivedMessageIds: [String] = []
    
    init(viewController: ViewController) {
        self.viewController = viewController
    }
    
    // Static method to add message listener during SDK initialization
   static func setupMessageListener() {
       print("正在设置消息监听器...")
       // 强制移除之前的监听器
//       EMClient.shared().chatManager?.remove(MessageListener.shared)
       // 重新添加监听器
       EMClient.shared().chatManager?.add(MessageListener.shared, delegateQueue: nil)
       print("消息监听器设置完成")
   }
    
    // Singleton message listener class
    class MessageListener: NSObject, EMChatManagerDelegate {
        static let shared = MessageListener()
        
        private override init() {
            super.init()
        }
        
        func messagesDidReceive(_ aMessages: [EMChatMessage]) {
            for message in aMessages {
                print("[MessageListener] Received message - ID: \(message.messageId), From: \(message.from), To: \(message.to), ChatType: \(message.chatType.rawValue)")
                
                // Store message ID in the array
                if message.chatType == .groupChat || message.chatType == .chat || message.chatType == .chatRoom {
                    test_remove_group_member.receivedMessageIds.append(message.messageId)
                    print("[MessageListener] Added message ID to array: \(message.messageId), Total count: \(test_remove_group_member.receivedMessageIds.count)")
                }
                
                // Handle different message types
                if let textBody = message.body as? EMTextMessageBody {
                    print("[MessageListener] Text content: \(textBody.text)")
                }
            }
        }
        
        func messagesInfoDidRecall(_ aRecallMessagesInfo: [EMRecallMessageInfo]) {
            for info in aRecallMessagesInfo {
                print("[MessageListener] Message recalled - ID: \(info.recallMessageId), By: \(info.recallBy)")
            }
        }
        
        func messageStatusDidChange(_ aMessage: EMChatMessage, error aError: EMError?) {
            print("[MessageListener] Message status changed - ID: \(aMessage.messageId), Status: \(aMessage.status.rawValue)")
        }
        
        func onMessageContentChanged(_ message: EMChatMessage, operatorId: String, operationTime: UInt) {
            print("[MessageListener] Message content changed - ID: \(message.messageId), Operator: \(operatorId)")
        }
    }
    
    func printLog(_ log: Any...) {
        viewController?.printLog(log)
    }
    
    // Modified method to use stored message IDs instead of input parameter
    func test_remove_group_meber_message_case(messageIds: [String]) {
        // Check if we have enough stored messages
        if messageIds.isEmpty {
            printLog("没有找到要撤回的消息，请先发送一些消息")
            return
        }
        
        printLog("当前收集到的消息ID: \(messageIds)")
        
        // 创建 一个测试群组，群组里面 有 创建者(du001)、管理员(du002)、普通成员(du003)、普通成员(du004)（已经通过restapi创建好了）
        // 撤销已经发送的消息（通过UI输入一个预置的消息id的数组: messages 是json格式的字符串，可以转换为字符串数组对象）
        // case0.0.0.1: 群组，创建者(du001)撤销消息
        // case0.0.0.2: 群组，创建者(du001)撤销超时的消息
        // case0.0.0.3: 群组，管理员(du002)撤销消息
        // case0.0.0.4: 群组，管理员(du002)撤销超时的消息
        // case0.0.0.5: 群组，普通成员(du003)撤销消息
        // case0.0.0.6: 群组，普通成员(du003)撤销超时的消息
        
        // 使用已创建好的测试群组ID
        let testGroupId = "278481563877379"
        
        // 测试用户
        let creatorId = "du001"    // 创建者
        let adminId = "du002"      // 管理员
        let memberId = "du003"     // 普通成员
        var currentId = EMClient.shared().currentUsername!
        
        if messageIds.isEmpty {
            printLog("没有找到要撤回的消息")
            return
        }
        
        // 辅助函数：撤回消息
        func recallMessage(by userId: String, messageId: String, caseId: String, completion: @escaping (Bool) -> Void) {
            printLog("[\(caseId)] [\(userId)]准备撤回消息")
            
            // 撤回消息
            EMClient.shared().chatManager?.recallMessage(withMessageId: messageId, completion: { error in
                if let error = error {
                    self.printLog("[\(caseId)] [\(userId)]撤回消息失败: \(error.errorDescription ?? "")")
                    completion(false)
                } else {
                    self.printLog("[\(caseId)] [\(userId)]成功撤回消息，ID: \(messageId)")
                    completion(true)
                }
            })
        }
        
        // 执行测试用例
        func runTest(caseId: String, description: String, userId: String, messageId: String, duration: Double = 2.0) {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.printLog("开始执行测试用例[\(caseId)]: \(description)")
                recallMessage(by: userId, messageId: messageId, caseId: caseId) { success in
                    self.printLog("测试用例[\(caseId)]执行" + (success ? "成功" : "失败"))
                }
            }
        }
        
        // 从存储的消息列表中获取消息ID
        let messageIds = test_remove_group_member.receivedMessageIds
        
        // 执行各个测试用例
        let requiredCount = 6
        if messageIds.count < requiredCount {
            printLog("可用的消息ID数量不足，需要至少\(requiredCount)个，实际提供了\(messageIds.count)个")
            printLog("将使用可用的消息ID进行测试")
        }
        
        // 将尽可能多地执行测试用例
        var index = 0
        var duration = 2.0

        for messageId in messageIds {
            if index < messageIds.count {
                runTest(caseId: "case0.0.0.x", description: "群组撤销消息",
                        userId: currentId, messageId: messageIds[index], duration: duration)
                duration += 2.0
            }
//            // case0.0.0.1: 群组，创建者(du001)撤销消息
//            if index < messageIds.count {
//                runTest(caseId: "case0.0.0.1", description: "群组，创建者撤销消息", 
//                        userId: creatorId, messageId: messageIds[index], duration: duration)
//                duration += 2.0
//            }
            
//            // case0.0.0.2: 群组，创建者(du001)撤销超时的消息
//            if index < messageIds.count {
//                runTest(caseId: "case0.0.0.2", description: "群组，创建者撤销超时消息", 
//                        userId: creatorId, messageId: messageIds[index], duration: duration)
//                duration += 2.0
//            }
//            
//            // case0.0.0.3: 群组，管理员(du002)撤销消息
//            if index < messageIds.count {
//                runTest(caseId: "case0.0.0.3", description: "群组，管理员撤销消息", 
//                        userId: adminId, messageId: messageIds[index], duration: duration)
//                duration += 2.0
//            }
//            
//            // case0.0.0.4: 群组，管理员(du002)撤销超时的消息
//            if index < messageIds.count {
//                runTest(caseId: "case0.0.0.4", description: "群组，管理员撤销超时消息", 
//                        userId: adminId, messageId: messageIds[index], duration: duration)
//                duration += 2.0
//            }
//            
//            // case0.0.0.5: 群组，普通成员(du003)撤销消息
//            if index < messageIds.count {
//                runTest(caseId: "case0.0.0.5", description: "群组，普通成员撤销消息", 
//                        userId: memberId, messageId: messageIds[index], duration: duration)
//                duration += 2.0
//            }
//            
//            // case0.0.0.6: 群组，普通成员(du003)撤销超时的消息
//            if index < messageIds.count {
//                runTest(caseId: "case0.0.0.6", description: "群组，普通成员撤销超时消息", 
//                        userId: memberId, messageId: messageIds[index], duration: duration)
//                duration += 2.0
//            }
            index += 1
        }
        
        
        
        // Clear the message IDs array after all tests are completed
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 2.0) {
            self.printLog("所有测试用例已执行完毕，清空消息ID数组")
            test_remove_group_member.receivedMessageIds.removeAll()
        }
        
        printLog("所有测试用例已排队执行，请查看结果")
    }
    
    // Keep the original method for backward compatibility
    func test_remove_group_meber_message_case() {
        // Call the new implementation
        test_remove_group_meber_message_case(messageIds: test_remove_group_member.receivedMessageIds)
    }
    
    func test_remove_group_member_api() {
        // https://j1.private.easemob.com/browse/HIM-15823
        // 创建 一个测试群组，群组里面 有 创建者(du001)、管理员(du002)、普通成员(du003)、普通成员(du004)（已经通过restapi创建好了）
        // case0.0.0.1: 群组，普通成员(du003)发送消息，自己撤回
        // case0.0.0.2: 群组，普通成员(du003)发送消息，普通成员(du004)撤回
        // case0.0.0.3: 群组，普通成员(du003)发送消息，自己超时撤回
        // case0.0.0.4: 群组，普通成员(du003)发送消息，管理员(du002)撤回
        // case0.0.0.5: 群组，普通成员(du003)发送消息，管理员(du002)超时撤回
        // case0.0.0.6: 群组，普通成员(du003)发送消息，创建者(du001)撤回
        // case0.0.0.7: 群组，普通成员(du003)发送消息，创建者(du001)超时撤回
        // case0.0.0.8: 群组，管理员(du002)发送消息，创建者(du001)撤回
        // case0.0.0.9: 群组，创建者(du001)发送消息，普通成员(du003)撤回
        // case0.0.1.0: 单聊，(du001)发送消息，(du002)撤回
        // case0.0.1.1: 单聊，(du001)发送消息，(du001)撤回
        // case0.1.0.0: 聊天室，普通成员(du003)发送消息，创建者(du001)撤回
        // case0.1.0.1: 聊天室，普通成员(du003)发送消息，管理员(du002)撤回
        // case1.0.0.0: 
        // 撤销消息示例: EMClient.shared().chatManager?.recallMessage(withMessageId: <#T##String#>)
        // 创建群组这样调用
//        var error: EMError? = nil
//        let opt: EMGroupOptions? = nil
//        EMClient.shared().groupManager?.createGroup(withSubject: "test_remove_group_member_api_i", description: "test_remove_group_member_api_i_name", invitees: ["du001", "du002", "du003", "du004"], message: "create group", setting: opt, error: &error)
//        获取当前登录用户: EMClient.shared().currentUsername
        
        // 使用已创建好的测试群组ID
        let testGroupId = "278468112744449" // 使用现有的groupId变量
        let testChatroomId = "278468009984001" // 使用现有的chatroomId变量
        
        // 测试用户
        let creatorId = "du001"    // 创建者
        let adminId = "du002"      // 管理员
        let memberId = "du003"     // 普通成员
        let otherMemberId = "du004" // 另一个普通成员
        
        // 辅助函数：发送消息并返回消息ID
        func sendGroupMessage(from: String, to: String, text: String, completion: @escaping (String?) -> Void) {
            // 直接发送消息，假设已登录
            self.printLog("[\(from)]准备发送消息")
            
            // 发送消息
            let body = EMTextMessageBody(text: text)
            let msg = EMChatMessage(conversationID: to, body: body, ext: nil)
            msg.chatType = .groupChat
            
            EMClient.shared().chatManager?.send(msg, progress: nil, completion: { message, error in
                if let error = error {
                    self.printLog("[\(from)]发送消息失败: \(error.errorDescription ?? "")")
                    completion(nil)
                } else {
                    self.printLog("[\(from)]成功发送消息，ID: \(message?.messageId ?? "")")
                    completion(message?.messageId)
                }
            })
        }
        
        // 辅助函数：撤回消息
        func recallMessage(by: String, messageId: String, completion: @escaping (Bool) -> Void) {
            // 直接撤回消息，假设已登录
            self.printLog("[\(by)]准备撤回消息")
            
            // 撤回消息
            EMClient.shared().chatManager?.recallMessage(withMessageId: messageId, completion: { error in
                if let error = error {
                    self.printLog("[\(by)]撤回消息失败: \(error.errorDescription ?? "")")
                    completion(false)
                } else {
                    self.printLog("[\(by)]成功撤回消息，ID: \(messageId)")
                    completion(true)
                }
            })
        }
        
        // 辅助函数：发送单聊消息
        func sendChatMessage(from: String, to: String, text: String, completion: @escaping (String?) -> Void) {
            // 直接发送消息，假设已登录
            self.printLog("[\(from)]准备发送单聊消息")
            
            // 发送消息
            let body = EMTextMessageBody(text: text)
            let msg = EMChatMessage(conversationID: to, body: body, ext: nil)
            msg.chatType = .chat
            
            EMClient.shared().chatManager?.send(msg, progress: nil, completion: { message, error in
                if let error = error {
                    self.printLog("[\(from)]发送单聊消息失败: \(error.errorDescription ?? "")")
                    completion(nil)
                } else {
                    self.printLog("[\(from)]成功发送单聊消息，ID: \(message?.messageId ?? "")")
                    completion(message?.messageId)
                }
            })
        }
        
        // 辅助函数：发送聊天室消息
        func sendChatroomMessage(from: String, to: String, text: String, completion: @escaping (String?) -> Void) {
            // 直接加入聊天室，假设已登录
            self.printLog("[\(from)]准备加入聊天室")
            
            // 加入聊天室
            EMClient.shared().roomManager?.joinChatroom(to, completion: { chatroom, error in
                if let error = error {
                    self.printLog("[\(from)]加入聊天室失败: \(error.errorDescription ?? "")")
                    completion(nil)
                    return
                }
                
                self.printLog("[\(from)]成功加入聊天室，准备发送消息")
                
                // 发送消息
                let body = EMTextMessageBody(text: text)
                let msg = EMChatMessage(conversationID: to, body: body, ext: nil)
                msg.chatType = .chatRoom
                
                EMClient.shared().chatManager?.send(msg, progress: nil, completion: { message, error in
                    if let error = error {
                        self.printLog("[\(from)]发送聊天室消息失败: \(error.errorDescription ?? "")")
                        completion(nil)
                    } else {
                        self.printLog("[\(from)]成功发送聊天室消息，ID: \(message?.messageId ?? "")")
                        completion(message?.messageId)
                    }
                })
            })
        }
        
        // 执行测试用例
        func runTest(caseId: String, description: String, testFunc: @escaping () -> Void) {
            self.printLog("开始执行测试用例[\(caseId)]: \(description)")
            testFunc()
        }
        
        // 测试用例的执行
        // case0.0.0.1: 群组，普通成员(du003)发送消息，自己撤回
        runTest(caseId: "case0.0.0.1", description: "群组，普通成员发送消息，自己撤回") {
            sendGroupMessage(from: memberId, to: testGroupId, text: "测试消息from\(memberId) - case0.0.0.1") { messageId in
                guard let messageId = messageId else { return }
                
                // 延迟1秒后撤回消息
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    recallMessage(by: memberId, messageId: messageId) { success in
                        self.printLog("测试用例[case0.0.0.1]执行" + (success ? "成功" : "失败"))
                    }
                }
            }
        }
        
        // case0.0.0.2: 群组，普通成员(du003)发送消息，普通成员(du004)撤回
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            runTest(caseId: "case0.0.0.2", description: "群组，普通成员发送消息，普通成员撤回") {
                sendGroupMessage(from: memberId, to: testGroupId, text: "测试消息from\(memberId) - case0.0.0.2") { messageId in
                    guard let messageId = messageId else { return }
                    
                    // 延迟1秒后撤回消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        recallMessage(by: otherMemberId, messageId: messageId) { success in
                            self.printLog("测试用例[case0.0.0.2]执行" + (success ? "成功" : "失败"))
                        }
                    }
                }
            }
        }
        
        // case0.0.0.4: 群组，普通成员(du003)发送消息，管理员(du002)撤回
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            runTest(caseId: "case0.0.0.4", description: "群组，普通成员发送消息，管理员撤回") {
                sendGroupMessage(from: memberId, to: testGroupId, text: "测试消息from\(memberId) - case0.0.0.4") { messageId in
                    guard let messageId = messageId else { return }
                    
                    // 延迟1秒后撤回消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        recallMessage(by: adminId, messageId: messageId) { success in
                            self.printLog("测试用例[case0.0.0.4]执行" + (success ? "成功" : "失败"))
                        }
                    }
                }
            }
        }
        
        // case0.0.0.6: 群组，普通成员(du003)发送消息，创建者(du001)撤回
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            runTest(caseId: "case0.0.0.6", description: "群组，普通成员发送消息，创建者撤回") {
                sendGroupMessage(from: memberId, to: testGroupId, text: "测试消息from\(memberId) - case0.0.0.6") { messageId in
                    guard let messageId = messageId else { return }
                    
                    // 延迟1秒后撤回消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        recallMessage(by: creatorId, messageId: messageId) { success in
                            self.printLog("测试用例[case0.0.0.6]执行" + (success ? "成功" : "失败"))
                        }
                    }
                }
            }
        }
        
        // case0.0.0.8: 群组，管理员(du002)发送消息，创建者(du001)撤回
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
            runTest(caseId: "case0.0.0.8", description: "群组，管理员发送消息，创建者撤回") {
                sendGroupMessage(from: adminId, to: testGroupId, text: "测试消息from\(adminId) - case0.0.0.8") { messageId in
                    guard let messageId = messageId else { return }
                    
                    // 延迟1秒后撤回消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        recallMessage(by: creatorId, messageId: messageId) { success in
                            self.printLog("测试用例[case0.0.0.8]执行" + (success ? "成功" : "失败"))
                        }
                    }
                }
            }
        }
        
        // case0.0.1.0: 单聊，(du001)发送消息，(du002)撤回
        DispatchQueue.main.asyncAfter(deadline: .now() + 25.0) {
            runTest(caseId: "case0.0.1.0", description: "单聊，du001发送消息，du002撤回") {
                sendChatMessage(from: creatorId, to: adminId, text: "测试消息from\(creatorId) - case0.0.1.0") { messageId in
                    guard let messageId = messageId else { return }
                    
                    // 延迟1秒后撤回消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        recallMessage(by: adminId, messageId: messageId) { success in
                            self.printLog("测试用例[case0.0.1.0]执行" + (success ? "成功" : "失败"))
                        }
                    }
                }
            }
        }
        
        // case0.0.1.1: 单聊，(du001)发送消息，(du001)撤回
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            runTest(caseId: "case0.0.1.1", description: "单聊，du001发送消息，du001撤回") {
                sendChatMessage(from: creatorId, to: adminId, text: "测试消息from\(creatorId) - case0.0.1.1") { messageId in
                    guard let messageId = messageId else { return }
                    
                    // 延迟1秒后撤回消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        recallMessage(by: creatorId, messageId: messageId) { success in
                            self.printLog("测试用例[case0.0.1.1]执行" + (success ? "成功" : "失败"))
                        }
                    }
                }
            }
        }
        
        // case0.1.0.0: 聊天室，普通成员(du003)发送消息，创建者(du001)撤回
        DispatchQueue.main.asyncAfter(deadline: .now() + 35.0) {
            runTest(caseId: "case0.1.0.0", description: "聊天室，普通成员发送消息，创建者撤回") {
                sendChatroomMessage(from: memberId, to: testChatroomId, text: "测试消息from\(memberId) - case0.1.0.0") { messageId in
                    guard let messageId = messageId else { return }
                    
                    // 延迟1秒后撤回消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        recallMessage(by: creatorId, messageId: messageId) { success in
                            self.printLog("测试用例[case0.1.0.0]执行" + (success ? "成功" : "失败"))
                        }
                    }
                }
            }
        }
        
        // case0.1.0.1: 聊天室，普通成员(du003)发送消息，管理员(du002)撤回
        DispatchQueue.main.asyncAfter(deadline: .now() + 40.0) {
            runTest(caseId: "case0.1.0.1", description: "聊天室，普通成员发送消息，管理员撤回") {
                sendChatroomMessage(from: memberId, to: testChatroomId, text: "测试消息from\(memberId) - case0.1.0.1") { messageId in
                    guard let messageId = messageId else { return }
                    
                    // 延迟1秒后撤回消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        recallMessage(by: adminId, messageId: messageId) { success in
                            self.printLog("测试用例[case0.1.0.1]执行" + (success ? "成功" : "失败"))
                        }
                    }
                }
            }
        }
        
        // case0.0.0.9: 群组，创建者(du001)发送消息，普通成员(du003)撤回
        DispatchQueue.main.asyncAfter(deadline: .now() + 45.0) {
            runTest(caseId: "case0.0.0.9", description: "群组，创建者发送消息，普通成员撤回") {
                sendGroupMessage(from: creatorId, to: testGroupId, text: "测试消息from\(creatorId) - case0.0.0.9") { messageId in
                    guard let messageId = messageId else { return }
                    
                    // 延迟1秒后撤回消息
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        recallMessage(by: memberId, messageId: messageId) { success in
                            self.printLog("测试用例[case0.0.0.9]执行" + (success ? "成功" : "失败"))
                        }
                    }
                }
            }
        }
        
        // 注意：超时撤回的测试用例需要等待消息过期才能测试，这里只是示例
        // 实际测试中可能需要修改SDK的配置或者使用模拟的方式
        self.printLog("所有测试用例已安排执行，请等待结果")
    }
} 
