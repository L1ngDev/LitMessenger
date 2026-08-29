import Foundation
import SwiftUI

let APIBaseURL = "http://157.228.137.204/msg"

enum APIError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Неверный ответ сервера"
        case .server(let m): return m
        }
    }
}

final class SessionStore: ObservableObject {
    @Published var token: String?
    @Published var currentUser: User?

    init() {
        self.token = UserDefaults.standard.string(forKey: "lit_token")
    }

    var isLoggedIn: Bool { token != nil }

    func completeLogin(token: String, user: User) {
        self.token = token
        self.currentUser = user
        UserDefaults.standard.set(token, forKey: "lit_token")
    }

    func logout() {
        self.token = nil
        self.currentUser = nil
        UserDefaults.standard.removeObject(forKey: "lit_token")
    }
}

struct APIClient {

    static func request<T: Decodable>(_ path: String, method: String = "GET",
                                      params: [String: Any]? = nil,
                                      token: String? = nil) async throws -> T {
        guard let url = URL(string: APIBaseURL + path) else { throw APIError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let params {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: params)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let msg = try? JSONDecoder().decode([String: String].self, from: data),
               let e = msg["error"] {
                throw APIError.server(e)
            }
            throw APIError.invalidResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func login(username: String, password: String) async throws -> (token: String, user: User) {
        struct Res: Decodable { let token: String; let user: User }
        let r: Res = try await request("/api/login", method: "POST",
                                       params: ["username": username, "password": password])
        return (r.token, r.user)
    }

    static func register(username: String, password: String, displayName: String) async throws -> (token: String, user: User) {
        struct Res: Decodable { let token: String; let user: User }
        let r: Res = try await request("/api/register", method: "POST",
                                       params: ["username": username, "password": password, "display_name": displayName])
        return (r.token, r.user)
    }

    static func me(token: String) async throws -> User {
        try await request("/api/me", token: token)
    }

    static func searchUsers(q: String, token: String) async throws -> [User] {
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await request("/api/users?q=\(enc)", token: token)
    }

    static func chats(token: String) async throws -> [Chat] {
        try await request("/api/chats", token: token)
    }

    static func createChat(withUserId: Int, token: String) async throws -> Int {
        struct Res: Decodable { let id: Int }
        let r: Res = try await request("/api/chats", method: "POST",
                                       params: ["with_user_id": withUserId], token: token)
        return r.id
    }

    static func createGroup(title: String, memberIds: [Int], token: String) async throws -> Int {
        struct Res: Decodable { let id: Int }
        let r: Res = try await request("/api/chats", method: "POST",
                                       params: ["type": "group", "title": title, "member_ids": memberIds], token: token)
        return r.id
    }

    static func chat(id: Int, token: String) async throws -> Chat {
        try await request("/api/chats/\(id)", token: token)
    }

    struct EmptyResponse: Decodable {}

    static func addMember(chatId: Int, userId: Int, token: String) async throws {
        _ = try await request<EmptyResponse>("/api/chats/\(chatId)/members", method: "POST",
                                             params: ["user_id": userId], token: token)
    }

    static func removeMember(chatId: Int, userId: Int, token: String) async throws {
        _ = try await request<EmptyResponse>("/api/chats/\(chatId)/members/\(userId)", method: "DELETE", token: token)
    }

    static func renameGroup(chatId: Int, title: String, token: String) async throws {
        _ = try await request<EmptyResponse>("/api/chats/\(chatId)", method: "PATCH",
                                             params: ["title": title], token: token)
    }

    static func search(q: String, token: String) async throws -> SearchResult {
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return try await request("/api/chats/search?q=\(enc)", token: token)
    }

    static func messages(chatId: Int, token: String) async throws -> [Message] {
        try await request("/api/chats/\(chatId)/messages", token: token)
    }

    static func sendMessage(chatId: Int, text: String, attachmentUrl: String?, token: String) async throws -> Message {
        var params: [String: Any] = ["text": text]
        if let attachmentUrl { params["attachment_url"] = attachmentUrl }
        return try await request("/api/chats/\(chatId)/messages", method: "POST", params: params, token: token)
    }

    static func upload(data: Data, fileName: String, mime: String, token: String) async throws -> String {
        guard let url = URL(string: APIBaseURL + "/api/upload") else { throw APIError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        struct Res: Decodable { let url: String }
        let r = try JSONDecoder().decode(Res.self, from: data)
        return r.url
    }
}
