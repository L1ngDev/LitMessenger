import SwiftUI
import PhotosUI

struct ChatView: View {
    @EnvironmentObject var session: SessionStore
    let chatId: Int

    @State private var messages: [Message] = []
    @State private var meta: Chat?
    @State private var text = ""
    @State private var busy = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0E1C3B), Color(hex: 0x10243F)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messages) { msg in
                                MessageBubble(
                                    msg: msg,
                                    isOwn: msg.senderId == session.currentUser?.id,
                                    showSender: msg.senderId != session.currentUser?.id && (meta?.isGroup ?? false)
                                )
                                .id(msg.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                HStack(spacing: 8) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "photo").foregroundStyle(.white)
                    }
                    .frame(width: 40, height: 40)
                    .liquidGlass(cornerRadius: 12)

                    TextField("Сообщение...", text: $text, axis: .vertical)
                        .padding(12)
                        .liquidGlass(cornerRadius: 18)

                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(Color(hex: 0x2AABEE))
                    }
                    .disabled(busy || text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle(meta?.titleText ?? "Чат")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: photoItem) { _ in Task { await handlePhoto() } }
    }

    func load() async {
        guard let token = session.token else { return }
        do {
            messages = try await APIClient.messages(chatId: chatId, token: token)
        } catch {}
        if let m = try? await APIClient.chat(id: chatId, token: token) {
            await MainActor.run { meta = m }
        }
    }

    func send() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let token = session.token else { return }
        busy = true
        Task {
            do {
                let m = try await APIClient.sendMessage(chatId: chatId, text: body,
                                                        attachmentUrl: nil, token: token)
                await MainActor.run { messages.append(m); text = "" }
            } catch {}
            await MainActor.run { busy = false }
        }
    }

    func handlePhoto() async {
        guard let item = photoItem, let token = session.token else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            await MainActor.run { photoItem = nil }
            return
        }
        busy = true
        do {
            let url = try await APIClient.upload(data: data,
                                                 fileName: "\(UUID().uuidString).jpg",
                                                 mime: "image/jpeg", token: token)
            let m = try await APIClient.sendMessage(chatId: chatId, text: "",
                                                    attachmentUrl: url, token: token)
            await MainActor.run { messages.append(m) }
        } catch {}
        await MainActor.run { busy = false; photoItem = nil }
    }
}

struct MessageBubble: View {
    let msg: Message
    let isOwn: Bool
    let showSender: Bool

    var body: some View {
        HStack {
            if isOwn { Spacer() }
            VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
                if showSender, let name = msg.senderName {
                    Text(name)
                        .font(.caption.bold())
                        .foregroundStyle(Color(hex: 0x2AABEE))
                        .padding(.horizontal, 4)
                }
                if let url = msg.attachmentUrl, let u = URL(string: url) {
                    AsyncImage(url: u) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView().tint(.white)
                    }
                    .frame(maxWidth: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if let text = msg.text, !text.isEmpty {
                    Text(text)
                        .foregroundStyle(.white)
                        .padding(10)
                        .liquidGlass(cornerRadius: 16)
                }
            }
            .frame(maxWidth: 260, alignment: isOwn ? .trailing : .leading)
            if !isOwn { Spacer() }
        }
        .padding(.horizontal, 10)
    }
}
