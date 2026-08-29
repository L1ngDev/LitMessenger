import SwiftUI

func fullUrl(_ s: String?) -> URL? {
    guard let s, !s.isEmpty else { return nil }
    if s.hasPrefix("http") { return URL(string: s) }
    return URL(string: APIBaseURL + s)
}

let tgIncoming = Color(red: 0.122, green: 0.173, blue: 0.227)
let tgOutgoing = Color(red: 0.169, green: 0.322, blue: 0.471)

struct ChatView: View {
    let chatId: Int
    @EnvironmentObject var session: SessionStore
    @State private var chat: Chat?
    @State private var messages: [Message] = []
    @State private var text = ""
    @State private var busy = false
    @State private var showInfo = false
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { idx, msg in
                            let prev = idx > 0 ? messages[idx - 1] : nil
                            let showDate = shouldShowDate(prev: prev, cur: msg)
                            let outgoing = isOutgoing(msg)
                            let showName = !outgoing && chat?.isGroup == true &&
                                (prev == nil || prev?.senderId != msg.senderId)
                            let showAvatar = !outgoing && chat?.isGroup == true &&
                                (prev == nil || prev?.senderId != msg.senderId)
                            VStack(spacing: 0) {
                                if showDate {
                                    DateSeparator(text: dateText(msg.createdAt))
                                        .padding(.top, 10).padding(.bottom, 4)
                                }
                                HStack(alignment: .bottom, spacing: 6) {
                                    if outgoing {
                                        Spacer(minLength: 48)
                                        Bubble(message: msg, outgoing: true, showName: false)
                                    } else {
                                        if showAvatar {
                                            AvatarView(title: msg.senderName ?? "?", size: 30)
                                                .padding(.bottom, 2)
                                        } else {
                                            Spacer().frame(width: 30)
                                        }
                                        Bubble(message: msg, outgoing: false, showName: showName)
                                        Spacer(minLength: 48)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.top, gapBefore(prev: prev, cur: msg))
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .background(Color(red: 0.090, green: 0.129, blue: 0.168))
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider().background(Color.white.opacity(0.08))
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

    func isOutgoing(_ m: Message) -> Bool {
        m.senderId == session.currentUser?.id
    }

    func shouldShowDate(prev: Message?, cur: Message) -> Bool {
        guard let cd = isoDate(cur.createdAt) else { return false }
        if let p = prev, let pd = isoDate(p.createdAt) {
            return !Calendar.current.isDate(pd, inSameDayAs: cd)
        }
        return true
    }

    func gapBefore(prev: Message?, cur: Message) -> CGFloat {
        if prev == nil { return 2 }
        if shouldShowDate(prev: prev, cur: cur) { return 2 }
        if let p = prev, p.senderId == cur.senderId { return 2 }
        return 8
    }

    func dateText(_ s: String?) -> String {
        guard let d = isoDate(s) else { return "" }
        if Calendar.current.isDateInToday(d) { return "Сегодня" }
        if Calendar.current.isDateInYesterday(d) { return "Вчера" }
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        f.locale = Locale(identifier: "ru_RU")
        return f.string(from: d)
    }
}

struct Bubble: View {
    let message: Message
    let outgoing: Bool
    let showName: Bool

    private var bg: Color { outgoing ? tgOutgoing : tgIncoming }

    var body: some View {
        VStack(alignment: outgoing ? .trailing : .leading, spacing: 2) {
            if showName, let name = message.senderName {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AvatarView.color(for: name))
                    .padding(.leading, 6)
            }
            HStack(alignment: .bottom, spacing: 5) {
                if let url = fullUrl(message.attachmentUrl) {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView().frame(height: 160)
                    }
                    .frame(maxWidth: 240, maxHeight: 260)
                    .cornerRadius(16)
                }
                if let txt = message.text, !txt.isEmpty {
                    Text(txt)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .padding(10)
                }
                HStack(spacing: 3) {
                    Text(msgTime(message.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.55))
                    if outgoing {
                        ReadTicks(read: false)
                    }
                }
                .padding(.bottom, 2)
                .padding(.trailing, 2)
            }
            .padding(EdgeInsets(top: 7, leading: 11, bottom: 7, trailing: 11))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(bg)
            )
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.74, alignment: outgoing ? .trailing : .leading)
    }
}

struct ReadTicks: View {
    let read: Bool
    var body: some View {
        HStack(spacing: -5) {
            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
            Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(read ? Color(red: 0.45, green: 0.75, blue: 1.0) : Color.white.opacity(0.6))
    }
}

struct DateSeparator: View {
    let text: String
    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.12)))
            Spacer()
        }
    }
}
