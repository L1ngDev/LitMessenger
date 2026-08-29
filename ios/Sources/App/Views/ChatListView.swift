import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var session: SessionStore
    @State private var chats: [Chat] = []
    @State private var query = ""
    @State private var searchResult: SearchResult?
    @State private var searching = false
    @State private var showNew = false
    @State private var path = NavigationPath()
    @State private var createdChatId: Int?

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color(red: 0.055, green: 0.086, blue: 0.129).ignoresSafeArea()
                List {
                    TLSearchField(text: $query)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                        .listRowBackground(Color.clear)
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        ForEach(chats) { chat in
                            ChatRow(chat: chat)
                                .contentShape(Rectangle())
                                .onTapGesture { path.append(chat.id) }
                                .listRowBackground(Color.clear)
                                .listRowSeparatorTint(Color.white.opacity(0.06))
                                .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                        }
                    } else if let sr = searchResult {
                        if !sr.users.isEmpty {
                            Section("Люди") {
                                ForEach(sr.users) { user in
                                    SearchUserRow(user: user)
                                        .contentShape(Rectangle())
                                        .onTapGesture { Task { await startChat(with: user.id) } }
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            }
                        }
                        if !sr.chats.isEmpty {
                            Section("Чаты") {
                                ForEach(sr.chats) { chat in
                                    ChatRow(chat: chat)
                                        .contentShape(Rectangle())
                                        .onTapGesture { path.append(chat.id) }
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            }
                        }
                        if !sr.messages.isEmpty {
                            Section("Сообщения") {
                                ForEach(sr.messages) { msg in
                                    SearchMessageRow(message: msg)
                                        .contentShape(Rectangle())
                                        .onTapGesture { path.append(msg.chatId) }
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                }
                            }
                        }
                        if sr.users.isEmpty && sr.chats.isEmpty && sr.messages.isEmpty {
                            Text("Ничего не найдено").foregroundColor(.gray)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Чаты")
            .glassToolbar()
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onChange(of: query) { _, _ in Task { await runSearch() } }
            .overlay(alignment: .bottomTrailing) {
                Button { showNew = true } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color(red: 0.20, green: 0.60, blue: 0.86)))
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 78)
            }
            .overlay(alignment: .bottom) {
                BottomTabBar(onSettings: { path.append("settings") })
            }
            .navigationDestination(for: Int.self) { id in
                ChatView(chatId: id).environmentObject(session)
            }
            .navigationDestination(for: String.self) { dest in
                if dest == "settings" { SettingsView().environmentObject(session) }
            }
            .sheet(isPresented: $showNew) {
                NewChatSheet().environmentObject(session)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    func load() async {
        guard let t = session.token else { return }
        do { chats = try await APIClient.chats(token: t) } catch { print(error) }
    }

    func runSearch() async {
        guard let t = session.token else { return }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { searchResult = nil; return }
        searching = true
        defer { searching = false }
        do { searchResult = try await APIClient.search(q: q, token: t) } catch { searchResult = nil }
    }

    func startChat(with userId: Int) async {
        guard let t = session.token else { return }
        do {
            let id = try await APIClient.createChat(withUserId: userId, token: t)
            showNew = false
            try? await Task.sleep(nanoseconds: 200_000_000)
            path.append(id)
            await load()
        } catch { print(error) }
    }
}

struct TLSearchField: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Поиск", text: $text)
                .foregroundColor(.white)
                .autocapitalization(.none)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
    }
}

struct ChatRow: View {
    let chat: Chat
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(title: chat.titleText, size: 52, cornerRadius: 13)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(chat.titleText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(chatTime(chat.updatedAt))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                HStack(spacing: 4) {
                    if chat.isGroup {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.gray).font(.system(size: 11))
                    }
                    Text(chat.lastMessage ?? "Нет сообщений")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct SearchUserRow: View {
    let user: User
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(title: user.displayName ?? user.username, size: 50)
            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName ?? user.username)
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Text("@" + user.username)
                    .font(.system(size: 14)).foregroundColor(.gray)
            }
        }
    }
}

struct SearchMessageRow: View {
    let message: Message
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "message.fill")
                .foregroundColor(.gray)
                .frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 3) {
                Text(message.senderName ?? "Сообщение")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Text(message.text ?? "Вложение")
                    .font(.system(size: 14)).foregroundColor(.gray).lineLimit(1)
            }
        }
    }
}

struct NewChatSheet: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) var dismiss
    @State private var mode: ChatMode = .private
    @State private var query = ""
    @State private var found: [User] = []
    @State private var groupTitle = ""
    @State private var selected: Set<Int> = []
    @State private var busy = false

    enum ChatMode: String, CaseIterable, Identifiable {
        case `private` = "Личный"; case group = "Группа"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Тип", selection: $mode) {
                    ForEach(ChatMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)
                .padding()

                if mode == .group {
                    TextField("Название группы", text: $groupTitle)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }

                TextField("Поиск пользователей", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: query) { _, _ in Task { await search() } }

                List {
                    ForEach(found) { u in
                        HStack {
                            AvatarView(title: u.displayName ?? u.username, size: 40)
                            VStack(alignment: .leading) {
                                Text(u.displayName ?? u.username).foregroundColor(.white)
                                Text("@" + u.username).foregroundColor(.gray).font(.footnote)
                            }
                            Spacer()
                            if mode == .group {
                                Image(systemName: selected.contains(u.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selected.contains(u.id) ? Color(red: 0.20, green: 0.60, blue: 0.86) : .gray)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if mode == .group {
                                if selected.contains(u.id) { selected.remove(u.id) }
                                else { selected.insert(u.id) }
                            } else {
                                Task { await createPrivate(u.id) }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Новый чат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                if mode == .group {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Создать") { Task { await createGroup() } }
                            .disabled(groupTitle.isEmpty || selected.isEmpty || busy)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    func search() async {
        guard let t = session.token else { return }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { found = []; return }
        do { found = try await APIClient.searchUsers(q: q, token: t) } catch { found = [] }
    }

    func createPrivate(_ userId: Int) async {
        guard let t = session.token else { return }
        busy = true; defer { busy = false }
        do { let _ = try await APIClient.createChat(withUserId: userId, token: t); dismiss() }
        catch { print(error) }
    }

    func createGroup() async {
        guard let t = session.token else { return }
        busy = true; defer { busy = false }
        do {
            let _ = try await APIClient.createGroup(title: groupTitle,
                                                    memberIds: Array(selected), token: t)
            dismiss()
        } catch { print(error) }
    }
}

struct BottomTabBar: View {
    let onSettings: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.08))
            HStack(spacing: 0) {
                Spacer()
                BottomTab(icon: "message.fill", label: "Чаты", active: true, action: {})
                Spacer()
                BottomTab(icon: "gear", label: "Настройки", active: false, action: onSettings)
                Spacer()
            }
            .padding(.vertical, 7)
        }
        .liquidGlass()
    }
}

struct BottomTab: View {
    let icon: String
    let label: String
    let active: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 22))
                Text(label).font(.system(size: 11))
            }
            .foregroundColor(active ? Color(red: 0.20, green: 0.60, blue: 0.86) : .gray)
        }
    }
}
