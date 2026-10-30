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
    case let member as EMConversationMember:
        return conversationMemberToJson(member)
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
    let bodies = message.bodies.enumerated().map { bodyToJson($0.offset, $0.element) }
    return [
        "messageId": message.messageId,
        "conversationId": message.conversationId,
        "from": message.from,
        "to": message.to,
        "direction": message.direction.rawValue,
        "status": message.status.rawValue,
        "timestamp": message.timestamp,
        "seq": message.seq,
        "bodies": bodies,
    ]
}

// 注意 iOS 的 body type 枚举从 1 开始（1 文本/2 图片/3 视频/4 位置/5 语音/6 文件/7 指令/8 自定义），与 Android 从 0 开始不同。
// downloadStatus：0 下载中 / 1 成功 / 2 失败 / 3 等待中。可选值为 nil 时对应字段不出现在输出中。
private func bodyToJson(_ index: Int, _ body: EMMessageBody) -> [String: Any] {
    var item: [String: Any] = ["index": index, "type": body.type.rawValue, "typeName": bodyTypeName(body.type)]
    switch body {
    case let text as EMTextMessageBody:
        item["text"] = text.text
    case let location as EMLocationMessageBody:
        item["latitude"] = location.latitude
        item["longitude"] = location.longitude
        item["address"] = location.address
        item["buildingName"] = location.buildingName
    case let cmd as EMCmdMessageBody:
        item["action"] = cmd.action
        item["deliverOnlineOnly"] = cmd.isDeliverOnlineOnly
    case let custom as EMCustomMessageBody:
        item["event"] = custom.event
        item["params"] = custom.customExt
    case let file as EMFileMessageBody:
        item["fileName"] = file.displayName
        item["localPath"] = file.localPath
        item["remotePath"] = file.remotePath
        item["fileSize"] = file.fileLength
        item["downloadStatus"] = file.downloadStatus.rawValue
        if let image = body as? EMImageMessageBody {
            item["width"] = Int(image.size.width)
            item["height"] = Int(image.size.height)
            item["isOriginalImage"] = image.isOriginalImage
            item["thumbnailLocalPath"] = image.thumbnailLocalPath
            item["thumbnailRemotePath"] = image.thumbnailRemotePath
            item["thumbnailFileSize"] = image.thumbnailFileLength
            item["thumbnailDownloadStatus"] = image.thumbnailDownloadStatus.rawValue
            item["bigImageLocalPath"] = image.bigImageLocalPath
            item["bigImageRemotePath"] = image.bigImageRemotePath
            item["bigImageDownloadStatus"] = image.bigImageDownloadStatus.rawValue
        } else if let video = body as? EMVideoMessageBody {
            item["duration"] = video.duration
            item["thumbnailLocalPath"] = video.thumbnailLocalPath
            item["thumbnailRemotePath"] = video.thumbnailRemotePath
            item["thumbnailWidth"] = Int(video.thumbnailSize.width)
            item["thumbnailHeight"] = Int(video.thumbnailSize.height)
            item["thumbnailDownloadStatus"] = video.thumbnailDownloadStatus.rawValue
        } else if let voice = body as? EMVoiceMessageBody {
            item["duration"] = voice.duration
        }
    default:
        break
    }
    return item
}

private func bodyTypeName(_ type: EMMessageBodyType) -> String {
    switch type {
    case .text: return "TXT"
    case .image: return "IMAGE"
    case .video: return "VIDEO"
    case .location: return "LOCATION"
    case .voice: return "VOICE"
    case .file: return "FILE"
    case .cmd: return "CMD"
    case .custom: return "CUSTOM"
    default: return "UNKNOWN"
    }
}

private func conversationToJson(_ conversation: EMConversation) -> [String: Any] {
    var json: [String: Any] = [
        "conversationId": conversation.conversationId,
        "isPinned": conversation.isPinned,
        "pinnedTime": conversation.pinnedTime,
        "unreadMessagesCount": conversation.unreadMessagesCount,
        "updatedAt": conversation.updatedAt,
        "markValue": conversation.markValue,
        "conversationName": conversation.conversationName,
        "conversationAvatar": conversation.conversationAvatar,
        "allBlocked": conversation.allBlocked,
        "blocked": conversation.blocked,
        "disabled": conversation.disabled,
        "archived": conversation.archived,
        "totalCount": conversation.totalCount,
        "createAt": conversation.createAt,
        "joinedTimestamp": conversation.joinedTimestamp,
        "role": conversation.role,
        "groupOwner": conversation.groupOwner,
        "seq": conversation.seq,
        "sessionRecordId": conversation.sessionRecordId,
    ]
    if let latest = conversation.latestMessage { json["latestMessage"] = messageToJson(latest) }
    return json
}

private func conversationMemberToJson(_ member: EMConversationMember) -> [String: Any] {
    [
        "memberId": member.memberId,
        "username": member.username,
        "role": member.role,
        "joinedTimestamp": member.joinedTimestamp,
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
        RTEPlus 消息模型不再暴露 ChatType，to 按会话 ID / 接收方 ID 填写。
        成功时 data 为发送完成后的消息 JSON，messageId 已是服务器下发的 ID。
        """,
        paramsTemplate: """
        {
          "to": "targetId",
          "content": "hello"
        }
        """,
        invoke: { params in
            let to = try requiredString(params, "to")
            let content = try requiredString(params, "content")
            let manager: IEMChatManager = try requireManager(EMClient.shared().chatManager)
            let message = EMChatMessage(conversationID: to,
                                        body: EMTextMessageBody(text: content),
                                        ext: nil)
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
        name: "ConversationManager.getConversationFromServer",
        group: "ConversationManager",
        detail: """
        从服务端获取单个会话（对应 IEMConversationManager 的 getConversationFromServer:completion:）。
        data 为会话快照，包含置顶、未读数、资料、成员数、seq 和 latestMessage 等字段。
        """,
        paramsTemplate: """
        {
          "conversationId": "conversationId"
        }
        """,
        invoke: { params in
            let conversationId = try requiredString(params, "conversationId")
            let manager: IEMConversationManager = try requireManager(EMClient.shared().conversationManager)
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<EMConversation, Error>) in
                manager.getConversationFromServer(conversationId) { conversation, error in
                    if let error {
                        continuation.resume(throwing: error.apiError)
                    } else if let conversation {
                        continuation.resume(returning: conversation)
                    } else {
                        continuation.resume(throwing: ApiInvokeError(code: -1, message: "getConversationFromServer 回调中 conversation 与 error 均为空"))
                    }
                }
            }
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
        name: "ConversationManager.getConversationMembersFromServer",
        group: "ConversationManager",
        detail: """
        分页获取会话成员（对应 IEMConversationManager 的 getConversationMembersFromServer:limit:cursor:sort:completion:）。
        limit 取值 [1,100]，传 0 使用服务端默认值；cursor 传空字符串表示首页；sort：0 升序 / 1 降序。
        返回 data 为 {"cursor": "...", "list": [成员 JSON...]}；cursor 为空表示没有下一页。
        """,
        paramsTemplate: """
        {
          "conversationId": "conversationId",
          "limit": 20,
          "cursor": "",
          "sort": 0
        }
        """,
        invoke: { params in
            let conversationId = try requiredString(params, "conversationId")
            let limit = params["limit"] as? Int ?? 20
            guard limit >= 0, limit <= 100 else {
                throw ApiInvokeError(code: -1, message: "limit 取值范围为 [0,100]")
            }
            let cursor = params["cursor"] as? String ?? ""
            let sortRaw = params["sort"] as? Int ?? 0
            guard let sort = EMSortOrder(rawValue: sortRaw) else {
                throw ApiInvokeError(code: -1, message: "sort 只支持 0/1")
            }
            let manager: IEMConversationManager = try requireManager(EMClient.shared().conversationManager)
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Any], Error>) in
                manager.getConversationMembers(fromServer: conversationId,
                                               limit: limit,
                                               cursor: cursor.isEmpty ? nil : cursor,
                                               sort: sort) { result, error in
                    if let error {
                        continuation.resume(throwing: error.apiError)
                    } else if let result {
                        continuation.resume(returning: [
                            "cursor": result.cursor ?? "",
                            "list": (result.list ?? []).map { toJsonSafe($0) ?? NSNull() },
                        ])
                    } else {
                        continuation.resume(throwing: ApiInvokeError(code: -1, message: "getConversationMembersFromServer 回调中 result 与 error 均为空"))
                    }
                }
            }
        }
    ),
    ApiEntry(
        name: "ChatManager.loadMessagesFromConversation",
        group: "ChatManager",
        detail: """
        按会话从新到旧分页加载消息（对应 IEMChatManager 的 loadMessagesFromConversation:cursor:pageSize:completion:）。
        本地 seq 链有缺口时 SDK 会先从服务端漫游补齐。cursor 传空字符串从最新开始；pageSize 取值 [1,400]。
        返回 data 为 {"cursor": "...", "list": [消息 JSON...]}；cursor 为空表示没有更多历史消息。
        """,
        paramsTemplate: """
        {
          "conversationId": "conversationId",
          "cursor": "",
          "pageSize": 20
        }
        """,
        invoke: { params in
            let conversationId = try requiredString(params, "conversationId")
            let cursor = params["cursor"] as? String ?? ""
            let pageSize = params["pageSize"] as? Int ?? 20
            guard pageSize >= 1, pageSize <= 400 else {
                throw ApiInvokeError(code: -1, message: "pageSize 取值范围为 [1,400]")
            }
            let manager: IEMChatManager = try requireManager(EMClient.shared().chatManager)
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String: Any], Error>) in
                manager.loadMessages(fromConversation: conversationId,
                                     cursor: cursor.isEmpty ? nil : cursor,
                                     pageSize: pageSize) { result, error in
                    if let error {
                        continuation.resume(throwing: error.apiError)
                    } else if let result {
                        continuation.resume(returning: [
                            "cursor": result.cursor ?? "",
                            "list": (result.list ?? []).map { toJsonSafe($0) ?? NSNull() },
                        ])
                    } else {
                        continuation.resume(throwing: ApiInvokeError(code: -1, message: "loadMessagesFromConversation 回调中 result 与 error 均为空"))
                    }
                }
            }
        }
    ),
]
