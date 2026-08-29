import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var session: SessionStore
    @State private var chats: [Chat] = []
    @State private var query = ""
    @State private var showNew = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x0E1C3B), Color(hex: 0x10243F)],
                               startPoint: .top, endPoint: .bottom).ignoresSafeArea()

                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    List {
                        ForEach(chats) { chat in
                            NavigationLink(value: chat.id) {
                                ChatRow(chat: chat)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await load() }
                } else {
                    SearchResultsView(query: query, path: $path)
                        .environmentObject(session)
                }
            }
            .searchable(text: $query, prompt: "Поиск")
            .navigationTitle("Чаты")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Выйти") { session.logout() }.foregroundStyle(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Image(systemName: "square.and.pencil") }
                }
            }
            .navigationDestination(for: Int.self) { chatId in
                ChatView(chatId: chatId)
            }
        }
        .sheet(isPresented: $showNew) {
            NewChatSheet(onCreated: { id in
                showNew = false
                path.append(id)
            })
            .environmentObject(session)
        }
        .task { await load() }
    }

    func load() async {
        guard let token = session.token else { return }
        do {
            chats = try await APIClient.chats(token: token)
        } catch {
            // ignore
        }
    }
}

struct ChatRow: View {
    let chat: Chat

    var body: some View {
        HStack(spacing: 12) {
            if chat.isGroup {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color(hex: 0x2AABEE)))
            } else {
                Circle()
                    .fill(Color(hex: 0x2AABEE))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Text(String((chat.otherUser?.displayName ?? chat.otherUser?.username ?? "?").prefix(1)))
                            .foregroundStyle(.white).bold()
                    )
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.titleText).foregroundStyle(.white).bold()
                Text(chat.lastMessage ?? "Нет сообщений")
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1).font(.subheadline)
            }
            Spacer()
        }
        .padding(12)
        .liquidGlass(cornerRadius: 16)
    }
}

// MARK: - Global search (Telegram-style)

struct SearchResultsView: View {
    @EnvironmentObject var session: SessionStore
    let query: String
    @Binding var path: NavigationPath
    @State private var result: SearchResult?
    @State private var busy = false

    var body: some View {
        List {
            if let result {
                if !result.chats.isEmpty {
                    Section("Чаты") {
                        ForEach(result.chats) { chat in
                            NavigationLink(value: chat.id) { SearchChatRow(chat: chat) }
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                if !result.users.isEmpty {
                    Section("Контакты") {
                        ForEach(result.users) { user in
                            Button { createPrivate(with: user) } label: { SearchUserRow(user: user) }
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                if !result.messages.isEmpty {
                    Section("Сообщения") {
                        ForEach(result.messages) { msg in
                            NavigationLink(value: msg.chatId) { SearchMessageRow(msg: msg) }
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                if result.chats.isEmpty && result.users.isEmpty && result.messages.isEmpty {
                    Text("Ничего не найдено")
                        .foregroundStyle(.white.opacity(0.6)).padding()
                }
            } else if busy {
                ProgressView().tint(.white)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .task { await run() }
        .onChange(of: query) { _ in Task { await run() } }
    }

    func run() async {
        guard let token = session.token else { return }
        busy = true
        do { result = try await APIClient.search(q: query, token: token) }
        catch { result = SearchResult(users: [], chats: [], messages: []) }
        busy = false
    }

    func createPrivate(with user: User) {
        guard let token = session.token else { return }
        Task {
            do {
                let id = try await APIClient.createChat(withUserId: user.id, token: token)
                await MainActor.run { path.append(id) }
            } catch {}
        }
    }
}

struct SearchChatRow: View {
    let chat: Chat
    var body: some View {
        HStack {
            if chat.isGroup {
                Image(systemName: "person.3.fill").foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(Circle().fill(Color(hex: 0x2AABEE)))
            } else {
                Circle().fill(Color(hex: 0x2AABEE)).frame(width: 38, height: 38)
                    .overlay(Text(String((chat.otherUser?.displayName ?? chat.otherUser?.username ?? "?").prefix(1))).foregroundStyle(.white))
            }
            Text(chat.titleText).foregroundStyle(.white).bold()
        }
    }
}

struct SearchUserRow: View {
    let user: User
    var body: some View {
        HStack {
            Circle().fill(Color(hex: 0x2AABEE)).frame(width: 38, height: 38)
                .overlay(Text(String((user.displayName ?? user.username).prefix(1))).foregroundStyle(.white))
            VStack(alignment: .leading) {
                Text(user.displayName ?? user.username).foregroundStyle(.white).bold()
                Text("@\(user.username)").foregroundStyle(.white.opacity(0.6)).font(.caption)
            }
        }
    }
}

struct SearchMessageRow: View {
    let msg: Message
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(msg.senderName ?? "Сообщение").foregroundStyle(.white.opacity(0.8)).font(.caption.bold())
            Text(msg.text ?? (msg.attachmentUrl != nil ? "📎 Вложение" : ""))
                .foregroundStyle(.white).lineLimit(1)
        }
    }
}

// MARK: - New chat / group composer

struct NewChatSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore
    @State private var mode: ChatMode = .private
    @State private var query = ""
    @State private var results: [User] = []
    @State private var selected = Set<Int>()
    @State private var groupName = ""
    @State private var busy = false
    let onCreated: (Int) -> Void

    enum ChatMode: String, CaseIterable, Identifiable {
        case `private` = "Личный"
        case group = "Группа"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x0E1C3B).ignoresSafeArea()
                VStack(spacing: 10) {
                    Picker("Тип", selection: $mode) {
                        ForEach(ChatMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if mode == .group {
                        TextField("Название группы", text: $groupName)
                            .padding(12).liquidGlass(cornerRadius: 12)
                            .padding(.horizontal)
                    }

                    TextField("Поиск пользователей", text: $query)
                        .padding(12).liquidGlass(cornerRadius: 12)
                        .padding(.horizontal)

                    List(results) { user in
                        Button { mode == .group ? toggle(user) : createPrivate(with: user) } label: {
                            HStack {
                                Circle().fill(Color(hex: 0x2AABEE)).frame(width: 38, height: 38)
                                    .overlay(Text(String((user.displayName ?? user.username).prefix(1))).foregroundStyle(.white))
                                VStack(alignment: .leading) {
                                    Text(user.displayName ?? user.username).foregroundStyle(.white).bold()
                                    Text("@\(user.username)").foregroundStyle(.white.opacity(0.6)).font(.caption)
                                }
                                Spacer()
                                if selected.contains(user.id) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: 0x2AABEE))
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)

                    if mode == .group {
                        Button {
                            createGroup()
                        } label: {
                            Text("Создать группу").bold().frame(maxWidth: .infinity)
                                .padding(12).liquidGlass(cornerRadius: 12)
                        }
                        .padding(.horizontal)
                        .disabled(busy || groupName.trimmingCharacters(in: .whitespaces).isEmpty || selected.isEmpty)
                    }
                    if busy { ProgressView().tint(.white) }
                }
                .padding(.top)
            }
            .navigationTitle(mode == .group ? "Новая группа" : "Новый чат")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } }
            }
        }
        .task { await search() }
        .onChange(of: query) { _ in Task { await search() } }
    }

    func toggle(_ user: User) {
        if selected.contains(user.id) { selected.remove(user.id) }
        else { selected.insert(user.id) }
    }

    func search() async {
        guard let token = session.token else { return }
        do { results = try await APIClient.searchUsers(q: query, token: token) }
        catch { results = [] }
    }

    func createPrivate(with user: User) {
        guard let token = session.token else { return }
        busy = true
        Task {
            do {
                let id = try await APIClient.createChat(withUserId: user.id, token: token)
                await MainActor.run { onCreated(id) }
            } catch { busy = false }
        }
    }

    func createGroup() {
        guard let token = session.token else { return }
        let ids = Array(selected)
        let name = groupName.trimmingCharacters(in: .whitespaces)
        guard !ids.isEmpty, !name.isEmpty else { return }
        busy = true
        Task {
            do {
                let id = try await APIClient.createGroup(title: name, memberIds: ids, token: token)
                await MainActor.run { onCreated(id) }
            } catch { busy = false }
        }
    }
}
