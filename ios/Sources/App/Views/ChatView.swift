import SwiftUI

func fullUrl(_ s: String?) -> URL? {
    guard let s, !s.isEmpty else { return nil }
    if s.hasPrefix("http") { return URL(string: s) }
    return URL(string: APIBaseURL + s)
}

struct ChatView: View {
    let chatId: Int
    @EnvironmentObject var session: SessionStore
    @State private var chat: Chat?
    @State private var messages: [Message] = []
    @State private var text = ""
    @State private var busy = false
    @State private var showInfo = false
    @State private var showPicker = false
    @State private var scrollID: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(messages) { msg in
                            MessageBubble(message: msg,
                                          isOutgoing: msg.senderId == session.currentUser?.id,
                                          showName: chat?.isGroup == true && msg.senderId != session.currentUser?.id)
                                .id(msg.id)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(Color(red: 0.05, green: 0.05, blue: 0.07))
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider().background(Color.white.opacity(0.1))
            HStack(spacing: 10) {
                Button { showPicker = true } label: {
                    Image(systemName: "photo").font(.system(size: 22)).foregroundColor(.gray)
                }
                TextField("Сообщение", text: $text, axis: .vertical)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.08)))
                    .foregroundColor(.white)
                Button { Task { await send() } } label: {
                    Image(systemName: text.trimmingCharacters(in: .whitespaces).isEmpty ? "mic" : "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color(red: 0.20, green: 0.60, blue: 0.86)))
                }
                .disabled(busy)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidGlass()
        }
        .navigationBarTitleDisplayMode(.inline)
        .glassToolbar()
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(chat?.titleText ?? "Чат")
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    if let c = chat, c.isGroup {
                        Text("\(c.members?.count ?? 0) участников")
                            .font(.system(size: 12)).foregroundColor(.gray)
                    } else if chat != nil {
                        Text("личный чат").font(.system(size: 12)).foregroundColor(.gray)
                    }
                }
            }
            if chat?.isGroup == true {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showInfo = true } label: {
                        Image(systemName: "info.circle").foregroundColor(.white)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showInfo) {
            if let c = chat { ChatInfoView(chat: c).environmentObject(session) }
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker { image in Task { await sendImage(image) } }
        }
        .task { await reload() }
        .refreshable { await reload() }
    }

    func reload() async {
        guard let t = session.token else { return }
        async let c = APIClient.chat(id: chatId, token: t)
        async let m = APIClient.messages(chatId: chatId, token: t)
        do {
            chat = try await c
            messages = try await m
        } catch { print(error) }
    }

    func send() async {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let t = session.token else { return }
        busy = true; defer { busy = false }
        text = ""
        do { let _ = try await APIClient.sendMessage(chatId: chatId, text: body, attachmentUrl: nil, token: t)
             await reload() } catch { print(error) }
    }

    func sendImage(_ image: UIImage) async {
        guard let t = session.token,
              let data = image.jpegData(compressionQuality: 0.7) else { return }
        busy = true; defer { busy = false }
        do {
            let url = try await APIClient.upload(data: data, fileName: "\(UUID().uuidString).jpg",
                                                 mime: "image/jpeg", token: t)
            let _ = try await APIClient.sendMessage(chatId: chatId, text: "", attachmentUrl: url, token: t)
            await reload()
        } catch { print(error) }
    }
}

struct MessageBubble: View {
    let message: Message
    let isOutgoing: Bool
    let showName: Bool

    var body: some View {
        HStack {
            if isOutgoing { Spacer(minLength: 40) }
            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 3) {
                if showName, let name = message.senderName {
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AvatarView.color(for: name))
                        .padding(.horizontal, 6)
                }
                if let url = fullUrl(message.attachmentUrl) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView().frame(height: 160)
                    }
                    .frame(maxWidth: 240)
                    .cornerRadius(16)
                }
                if let txt = message.text, !txt.isEmpty {
                    Text(txt)
                        .font(.system(size: 15))
                        .foregroundColor(isOutgoing ? .white : .white)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isOutgoing
                                      ? Color(red: 0.20, green: 0.60, blue: 0.86)
                                      : Color.white.opacity(0.12))
                        )
                }
                Text(msgTime(message.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 4)
            }
            if !isOutgoing { Spacer(minLength: 40) }
        }
    }
}
