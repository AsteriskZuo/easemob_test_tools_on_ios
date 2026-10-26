//
//  ApiTestRegistry.swift
//  sdkTest
//
//  API 调用页的注册表：iOS 没有运行时反射，API 名称到调用的映射需要手工注册。
//

import Foundation
@preconcurrency import HyphenateChat

/// 单个可调用 API 的注册项。
struct ApiEntry: Identifiable {
    let name: String           // 例如 "ChatManager.sendMessage"
    let group: String          // 例如 "ChatManager"
    let detail: String         // 参数约定与注意事项
    let paramsTemplate: String // 必填字段 JSON 模板
    let invoke: ([String: Any]) async throws -> Any?

    var id: String { name }
}

/// 统一错误格式：EMError 取 code/errorDescription，其他错误 code = -1。
struct ApiInvokeError: Error {
    let code: Int
    let message: String
}

extension EMError {
    var apiError: ApiInvokeError {
        ApiInvokeError(code: Int(code.rawValue), message: errorDescription ?? "")
    }
}

/// 调用注册项并包装成统一结果：
/// 成功 {"success": true, "data": ...}（无返回值则无 data），失败 {"success": false, "error": {"code": ..., "message": ...}}。
func runApi(_ entry: ApiEntry, params: [String: Any]) async -> [String: Any] {
    do {
        let value = try await entry.invoke(params)
        var result: [String: Any] = ["success": true]
        if let json = toJsonSafe(value) { result["data"] = json }
        return result
    } catch let error as ApiInvokeError {
        return ["success": false, "error": ["code": error.code, "message": error.message]]
    } catch {
        return ["success": false, "error": ["code": -1, "message": error.localizedDescription]]
    }
}

/// 把 SDK 返回值转换为可 JSON 序列化的结构（SDK 模型没有统一 toJson，按类型手写）。
func toJsonSafe(_ value: Any?) -> Any? {
    switch value {
    case nil:
        return nil
    case let string as String:
        return string
    case let number as NSNumber:
        return number
    case let message as EMChatMessage:
        return messageToJson(message)
    case let conversation as EMConversation:
        return conversationToJson(conversation)
    case let group as EMGroup:
        return groupToJson(group)
    case let contact as EMContact:
        return contactToJson(contact)
    case let array as [Any]:
        return array.map { toJsonSafe($0) ?? NSNull() }
    case let dict as [String: Any]:
        return dict.mapValues { toJsonSafe($0) ?? NSNull() }
    default:
        return String(describing: value!)
    }
}

private func messageToJson(_ message: EMChatMessage) -> [String: Any] {
    let bodies = message.bodies.enumerated().map { index, body -> [String: Any] in
        // 注意 iOS 的 body type 枚举从 1 开始（1 文本/2 图片/3 视频/4 位置/5 语音/6 文件），与 Flutter 从 0 开始不同。
        var item: [String: Any] = ["index": index, "type": body.type.rawValue]
        if let text = body as? EMTextMessageBody { item["text"] = text.text }
        return item
    }
    return [
        "messageId": message.messageId,
        "conversationId": message.conversationId,
        "from": message.from,
        "to": message.to,
        "chatType": message.chatType.rawValue,
        "status": message.status.rawValue,
        "timestamp": message.timestamp,
        "bodies": bodies,
    ]
}

private func conversationToJson(_ conversation: EMConversation) -> [String: Any] {
    var json: [String: Any] = [
        "conversationId": conversation.conversationId,
        "type": conversation.type.rawValue,
        "unreadMessagesCount": conversation.unreadMessagesCount,
        "messagesCount": conversation.messagesCount,
    ]
    if let latest = conversation.latestMessage { json["latestMessageId"] = latest.messageId }
    return json
}

private func groupToJson(_ group: EMGroup) -> [String: Any] {
    [
        "groupId": group.groupId,
        "groupName": group.groupName,
        "owner": group.owner,
        "description": group.description,
    ]
}

private func contactToJson(_ contact: EMContact) -> [String: Any] {
    var json: [String: Any] = [
        "userId": contact.userId,
        "addTimestamp": contact.addTimestamp,
    ]
    if let remark = contact.remark { json["remark"] = remark }
    return json
}

private func requiredString(_ params: [String: Any], _ key: String) throws -> String {
    guard let value = params[key] as? String, !value.isEmpty else {
        throw ApiInvokeError(code: -1, message: "缺少参数 \(key)（非空字符串）")
    }
    return value
}

private func requireManager<T>(_ manager: T?) throws -> T {
    guard let manager else {
        throw ApiInvokeError(code: -1, message: "SDK 未初始化，请先在「登录与初始化」页面初始化")
    }
    return manager
}

/// 已注册 API 列表。初始化与登录由「登录与初始化」页面负责，不在此注册。
let apiRegistry: [ApiEntry] = [
    ApiEntry(
        name: "ChatManager.sendMessage",
        group: "ChatManager",
        detail: """
        发送文本消息（对应 EMChatManager 的 sendMessage:progress:completion: 异步接口）。
        chatType：0 单聊 / 1 群聊 / 2 聊天室；群聊与聊天室的 to 填已加入的群 ID / 聊天室 ID。
        成功时 data 为发送完成后的消息 JSON，messageId 已是服务器下发的 ID。
        """,
        paramsTemplate: """
        {
          "to": "targetId",
          "chatType": 0,
          "content": "hello"
        }
        """,
        invoke: { params in
            let to = try requiredString(params, "to")
            let content = try requiredString(params, "content")
            let chatTypeRaw = params["chatType"] as? Int ?? 0
            guard let chatType = EMChatType(rawValue: chatTypeRaw) else {
                throw ApiInvokeError(code: -1, message: "chatType 只支持 0/1/2")
            }
            let manager: IEMChatManager = try requireManager(EMClient.shared().chatManager)
            let message = EMChatMessage(conversationID: to,
                                        body: EMTextMessageBody(text: content),
                                        ext: nil)
            message.chatType = chatType
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<EMChatMessage, Error>) in
                manager.send(message, progress: nil) { sent, error in
                    if let error {
                        continuation.resume(throwing: error.apiError)
                    } else if let sent {
                        continuation.resume(returning: sent)
                    } else {
                        continuation.resume(throwing: ApiInvokeError(code: -1, message: "sendMessage 回调中 message 与 error 均为空"))
                    }
                }
            }
        }
    ),
    ApiEntry(
        name: "ChatManager.getAllConversations",
        group: "ChatManager",
        detail: """
        从本地数据库加载全部会话（同步方法，对应 getAllConversations）。
        data 为会话数组，含 conversationId、type（0 单聊/1 群聊/2 聊天室）、unreadMessagesCount、messagesCount、latestMessageId。
        """,
        paramsTemplate: "{}",
        invoke: { _ in
            let manager: IEMChatManager = try requireManager(EMClient.shared().chatManager)
            return manager.getAllConversations() ?? []
        }
    ),
    ApiEntry(
        name: "ContactManager.getAllContacts",
        group: "ContactManager",
        detail: """
        获取本地数据库中的全部联系人（同步方法，对应 getAllContacts）。
        data 为联系人数组，含 userId、remark、addTimestamp。
        """,
        paramsTemplate: "{}",
        invoke: { _ in
            let manager: IEMContactManager = try requireManager(EMClient.shared().contactManager)
            return manager.getAllContacts() ?? []
        }
    ),
    ApiEntry(
        name: "GroupManager.getJoinedGroups",
        group: "GroupManager",
        detail: """
        获取本地缓存的当前用户已加入群组列表（同步方法，对应 getJoinedGroups）。
        data 为群组数组，含 groupId、groupName、owner、description。
        """,
        paramsTemplate: "{}",
        invoke: { _ in
            let manager: IEMGroupManager = try requireManager(EMClient.shared().groupManager)
            return manager.getJoinedGroups() ?? []
        }
    ),
]
