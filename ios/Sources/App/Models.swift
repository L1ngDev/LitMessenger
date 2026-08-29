import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let displayName: String?
    let avatar: String?

    enum CodingKeys: String, CodingKey {
        case id, username, avatar
        case displayName = "display_name"
    }
}

struct Chat: Codable, Identifiable, Hashable {
    let id: Int
    let type: String?
    let title: String?
    let creatorId: Int?
    let lastMessage: String?
    let updatedAt: String?
    let otherUser: User?
    let members: [User]?

    enum CodingKeys: String, CodingKey {
        case id, type, title, members
        case creatorId = "creator_id"
        case lastMessage = "last_message"
        case updatedAt = "updated_at"
        case otherUser = "other_user"
    }

    var isGroup: Bool { type == "group" }

    var titleText: String {
        if isGroup { return title ?? "Группа" }
        return otherUser?.displayName ?? otherUser?.username ?? "Чат"
    }
}

struct Message: Codable, Identifiable {
    let id: Int
    let chatId: Int
    let senderId: Int
    let text: String?
    let attachmentUrl: String?
    let createdAt: String?
    let senderName: String?

    enum CodingKeys: String, CodingKey {
        case id, text
        case chatId = "chat_id"
        case senderId = "sender_id"
        case attachmentUrl = "attachment_url"
        case createdAt = "created_at"
        case senderName = "sender_name"
    }
}

struct SearchResult: Decodable {
    let users: [User]
    let chats: [Chat]
    let messages: [Message]
}
