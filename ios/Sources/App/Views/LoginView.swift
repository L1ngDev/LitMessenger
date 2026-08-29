import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: SessionStore
    @State private var username = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isRegister = false
    @State private var errorMsg: String?
    @State private var busy = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2AABEE), Color(hex: 0x0E1C3B)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer().frame(height: 60)
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                Text("Lit Messenger")
                    .font(.largeTitle.bold()).foregroundStyle(.white)
                Text("твой приватный мессенджер")
                    .foregroundStyle(.white.opacity(0.8)).font(.subheadline)

                VStack(spacing: 12) {
                    TextField("Логин", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .padding(14)
                        .liquidGlass(cornerRadius: 14)

                    SecureField("Пароль", text: $password)
                        .padding(14)
                        .liquidGlass(cornerRadius: 14)

                    if isRegister {
                        TextField("Отображаемое имя", text: $displayName)
                            .padding(14)
                            .liquidGlass(cornerRadius: 14)
                    }

                    Button(action: submit) {
                        if busy {
                            ProgressView().tint(.white)
                        } else {
                            Text(isRegister ? "Создать аккаунт" : "Войти").bold()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .liquidGlass(cornerRadius: 14)
                    .foregroundStyle(.white)
                    .disabled(busy || username.isEmpty || password.isEmpty)
                }
                .padding(.horizontal, 28)

                Button(isRegister ? "Уже есть аккаунт? Войти" : "Нет аккаунта? Создать") {
                    isRegister.toggle()
                }
                .foregroundStyle(.white.opacity(0.9)).font(.footnote)

                if let errorMsg {
                    Text(errorMsg).foregroundStyle(.red).font(.footnote)
                        .padding(.horizontal, 28).multilineTextAlignment(.center)
                }
                Spacer()
            }
        }
    }

    func submit() {
        busy = true
        errorMsg = nil
        Task {
            do {
                let result = isRegister
                    ? try await APIClient.register(username: username, password: password,
                                                   displayName: displayName.isEmpty ? username : displayName)
                    : try await APIClient.login(username: username, password: password)
                await MainActor.run { session.completeLogin(token: result.token, user: result.user) }
            } catch {
                await MainActor.run { errorMsg = (error as? APIError)?.errorDescription ?? error.localizedDescription }
            }
            await MainActor.run { busy = false }
        }
    }
}
