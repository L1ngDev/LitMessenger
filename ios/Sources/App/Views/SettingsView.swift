import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    @State private var user: User?

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    AvatarView(title: (user?.displayName ?? user?.username) ?? "?", size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user?.displayName ?? user?.username ?? "Профиль")
                            .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                        if let u = user?.username {
                            Text("@" + u).font(.system(size: 14)).foregroundColor(.gray)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            Section("Основное") {
                SettingsRow(icon: "person.2.fill", title: "Участники и группы", color: .blue)
                SettingsRow(icon: "bell.fill", title: "Уведомления", color: .red)
                SettingsRow(icon: "lock.fill", title: "Конфиденциальность", color: .green)
            }
            .listRowBackground(Color.clear)

            Section("Прочее") {
                SettingsRow(icon: "questionmark.circle.fill", title: "Помощь", color: .orange)
                SettingsRow(icon: "info.circle.fill", title: "О приложении", color: .gray)
            }
            .listRowBackground(Color.clear)

            Section {
                Button {
                    session.logout()
                } label: {
                    HStack {
                        Spacer()
                        Text("Выйти из аккаунта")
                            .foregroundColor(.red).font(.system(size: 16, weight: .medium))
                        Spacer()
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle("Настройки")
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
        .preferredColorScheme(.dark)
    }

    func load() async {
        guard let t = session.token else { return }
        do { user = try await APIClient.me(token: t) } catch { user = session.currentUser }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(color))
            Text(title).foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray)
        }
    }
}
