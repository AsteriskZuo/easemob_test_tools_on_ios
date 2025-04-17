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
    
    init(viewController: ViewController) {
        self.viewController = viewController
    }
    
    func printLog(_ log: Any...) {
        viewController?.printLog(log)
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
        let testGroupId = "278387351420932" // 使用现有的groupId变量
        let testChatroomId = "278387868368900" // 使用现有的chatroomId变量
        
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
        
        // 注意：超时撤回的测试用例需要等待消息过期才能测试，这里只是示例
        // 实际测试中可能需要修改SDK的配置或者使用模拟的方式
        self.printLog("所有测试用例已安排执行，请等待结果")
    }
} 
