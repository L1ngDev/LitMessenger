import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    @State private var user: User?

    private var name: String { user?.displayName ?? user?.username ?? "Профиль" }
    private var username: String { user?.username ?? "" }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Profile header card
                HStack(spacing: 14) {
                    AvatarView(title: name, size: 60)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                        if !username.isEmpty {
                            Text("@" + username)
                                .font(.system(size: 14)).foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.gray)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.090, green: 0.129, blue: 0.168)))

                SettingsCard(title: "Аккаунт", rows: [
                    SettingsRow(icon: "person.fill", color: .blue, title: "Изменить имя", value: name),
                    SettingsRow(icon: "at", color: .blue, title: "Юзернейм", value: "@" + username),
                    SettingsRow(icon: "phone.fill", color: .green, title: "Номер телефона", value: "—"),
                    SettingsRow(icon: "info.circle.fill", color: .orange, title: "Био", value: "—"),
                ])

                SettingsCard(title: "Уведомления и звуки", rows: [
                    SettingsRow(icon: "bell.fill", color: .red, title: "Уведомления"),
                    SettingsRow(icon: "speaker.wave.2.fill", color: .red, title: "Звуки сообщений"),
                ])

                SettingsCard(title: "Конфиденциальность", rows: [
                    SettingsRow(icon: "lock.fill", color: .pink, title: "Конфиденциальность"),
                    SettingsRow(icon: "eye.slash.fill", color: .pink, title: "Блокировка экран"),
                ])

                SettingsCard(title: "Данные и память", rows: [
                    SettingsRow(icon: "chart.bar.fill", color: .purple, title: "Использование данных"),
                    SettingsRow(icon: "internaldrive.fill", color: .purple, title: "Память"),
                ])

                SettingsCard(title: "Внешний вид", rows: [
                    SettingsRow(icon: "paintbrush.fill", color: .blue, title: "Тема оформления", value: "Тёмная"),
                    SettingsRow(icon: "textformat.size", color: .blue, title: "Размер текста"),
                ])

                SettingsCard(title: "Чаты", rows: [
                    SettingsRow(icon: "bubble.left.fill", color: .green, title: "Оформление чатов"),
                    SettingsRow(icon: "globe", color: .green, title: "Язык"),
                ])

                Button {
                    session.logout()
                } label: {
                    Text("Выйти из аккаунта")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: 0.090, green: 0.129, blue: 0.168)))
                }
                .padding(.horizontal, 12)
            }
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .background(Color(red: 0.055, green: 0.086, blue: 0.129).ignoresSafeArea())
        .navigationTitle("Настройки")
        .glassToolbar()
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
    let color: Color
    let title: String
    var value: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .font(.system(size: 15))
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color))
            Text(title)
                .foregroundColor(.white)
                .font(.system(size: 15))
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 13))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

struct SettingsCard: View {
    var title: String? = nil
    let rows: [SettingsRow]

    var body: some View {
        VStack(spacing: 0) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 6)
            }
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    row
                    if i < rows.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.leading, 54)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.090, green: 0.129, blue: 0.168)))
        }
        .padding(.horizontal, 12)
    }
}
