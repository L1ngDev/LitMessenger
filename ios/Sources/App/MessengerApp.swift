import SwiftUI

@main
struct MessengerApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        Group {
            if session.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        TabView {
            ChatListView()
                .environmentObject(session)
                .tabItem { Label("Чаты", systemImage: "message.fill") }
            SettingsView()
                .environmentObject(session)
                .tabItem { Label("Настройки", systemImage: "gear") }
        }
        .preferredColorScheme(.dark)
    }
}
