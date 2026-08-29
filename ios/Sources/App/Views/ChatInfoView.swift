import SwiftUI

struct ChatInfoView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) var dismiss
    @State var chat: Chat
    @State private var query = ""
    @State private var found: [User] = []
    @State private var busy = false
    @State private var showRename = false
    @State private var newTitle = ""

    var isAdmin: Bool { chat.creatorId == session.currentUser?.id }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    AvatarView(title: chat.titleText, size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chat.titleText)
                            .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                        Text("\(chat.members?.count ?? 0) участников")
                            .font(.system(size: 14)).foregroundColor(.gray)
                    }
                    Spacer()
                    if isAdmin {
                        Button { newTitle = chat.titleText; showRename = true } label: {
                            Image(systemName: "pencil").foregroundColor(.blue)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            Section("Участники") {
                ForEach(chat.members ?? []) { u in
                    HStack(spacing: 12) {
                        AvatarView(title: u.displayName ?? u.username, size: 40)
                        VStack(alignment: .leading) {
                            Text(u.displayName ?? u.username).foregroundColor(.white)
                            Text("@" + u.username).foregroundColor(.gray).font(.footnote)
                        }
                        Spacer()
                        if isAdmin && u.id != session.currentUser?.id {
                            Button { Task { await remove(u.id) } } label: {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }
                        } else if u.id == session.currentUser?.id {
                            Button { Task { await leave() } } label: {
                                Text("Выйти").foregroundColor(.red)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }

            Section("Добавить участника") {
                TextField("Поиск", text: $query)
                    .onChange(of: query) { _, _ in Task { await search() } }
                    .listRowBackground(Color.clear)
                ForEach(found) { u in
                    HStack(spacing: 12) {
                        AvatarView(title: u.displayName ?? u.username, size: 40)
                        VStack(alignment: .leading) {
                            Text(u.displayName ?? u.username).foregroundColor(.white)
                            Text("@" + u.username).foregroundColor(.gray).font(.footnote)
                        }
                        Spacer()
                        Button { Task { await add(u.id) } } label: {
                            Image(systemName: "plus.circle.fill").foregroundColor(Color(red: 0.20, green: 0.60, blue: 0.86))
                        }
                    }
                    .contentShape(Rectangle())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("Информация")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Переименовать", isPresented: $showRename) {
            TextField("Название", text: $newTitle)
            Button("Готово") { Task { await rename() } }
            Button("Отмена", role: .cancel) {}
        }
        .preferredColorScheme(.dark)
    }

    func search() async {
        guard let t = session.token else { return }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { found = []; return }
        do { found = try await APIClient.searchUsers(q: q, token: t) } catch { found = [] }
    }

    func add(_ userId: Int) async {
        guard let t = session.token else { return }
        busy = true; defer { busy = false }
        do { try await APIClient.addMember(chatId: chat.id, userId: userId, token: t)
             chat = try await APIClient.chat(id: chat.id, token: t)
             found = []; query = "" } catch { print(error) }
    }

    func remove(_ userId: Int) async {
        guard let t = session.token else { return }
        busy = true; defer { busy = false }
        do { try await APIClient.removeMember(chatId: chat.id, userId: userId, token: t)
             chat = try await APIClient.chat(id: chat.id, token: t) } catch { print(error) }
    }

    func leave() async {
        guard let t = session.token, let me = session.currentUser?.id else { return }
        busy = true; defer { busy = false }
        do { try await APIClient.removeMember(chatId: chat.id, userId: me, token: t)
             dismiss() } catch { print(error) }
    }

    func rename() async {
        guard let t = session.token else { return }
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        busy = true; defer { busy = false }
        do { try await APIClient.renameGroup(chatId: chat.id, title: title, token: t)
             chat = try await APIClient.chat(id: chat.id, token: t) } catch { print(error) }
    }
}
