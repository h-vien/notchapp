import AVKit
import SwiftUI

struct NotchPanelView: View {
    @ObservedObject var store: ChatStore
    @ObservedObject var auth: TelegramAuthStore
    @Binding var isExpanded: Bool
    let topOcclusionHeight: CGFloat
    @State private var draft = ""
    @State private var viewedMediaMessageID: String?
    @FocusState private var composerFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            if isExpanded {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(NotchTheme.panelTint)
                    .overlay(alignment: .top) {
                        LinearGradient(
                            colors: [NotchTheme.glassHighlight, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 88)
                        .allowsHitTesting(false)
                    }

                VStack(spacing: 0) {
                    // This empty region aligns the expanded surface with the physical camera housing.
                    Color.clear
                        .frame(height: topOcclusionHeight)
                        .allowsHitTesting(false)

                    Group {
                        if auth.isReady { expandedContent } else { authContent }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            } else {
                // Transparent but hit-testable: the real display notch provides the black surface.
                Color.clear
                    .contentShape(Rectangle())
                    .accessibilityLabel("Open NotchChat")
            }
        }
        .clipShape(NotchShape(cornerRadius: isExpanded ? 24 : 0))
        .overlay {
            if isExpanded {
                NotchShape(cornerRadius: 24)
                    .stroke(NotchTheme.glassEdge, lineWidth: 0.75)
            }
        }
        .shadow(color: .black.opacity(isExpanded ? 0.32 : 0), radius: 24, y: 12)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isExpanded else { return }
            withAnimation(.snappy(duration: 0.34, extraBounce: 0.02)) { isExpanded = true }
        }
        .onExitCommand {
            if viewedMediaMessageID != nil {
                viewedMediaMessageID = nil
                return
            }
            withAnimation(.snappy(duration: 0.28, extraBounce: 0)) { isExpanded = false }
        }
        .preferredColorScheme(.dark)
    }

    private var expandedContent: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider().overlay(NotchTheme.separator)
                if store.selectedChat == nil {
                    chatList
                } else {
                    conversation
                }
            }

            if let messageID = viewedMediaMessageID,
               let message = store.selectedMessages.first(where: { $0.id == messageID }),
               let media = message.media {
                MediaViewer(media: media) {
                    withAnimation(.easeOut(duration: 0.16)) { viewedMediaMessageID = nil }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
    }

    private var authContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(NotchTheme.telegram)
                Text("Connect Telegram")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(NotchTheme.text)
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.24, extraBounce: 0)) { isExpanded = false }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(NotchIconButtonStyle())
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            Divider().overlay(NotchTheme.separator)
            TelegramAuthView(auth: auth)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            if store.selectedChat != nil {
                Button {
                    viewedMediaMessageID = nil
                    store.selectedChatID = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(NotchIconButtonStyle())
                .help("Back to chats")
            } else {
                connectionDot
            }

            Text(store.selectedChat?.title ?? "Messages")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(NotchTheme.text)
                .lineLimit(1)
            Spacer()
            Button {
                withAnimation(.snappy(duration: 0.28, extraBounce: 0)) { isExpanded = false }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(NotchIconButtonStyle())
            .keyboardShortcut(.escape, modifiers: [])
            .help("Collapse")
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
    }

    private var connectionDot: some View {
        Circle()
            .fill(store.connection == .online ? Color.green : NotchTheme.secondary)
            .frame(width: 7, height: 7)
            .shadow(color: store.connection == .online ? Color.green.opacity(0.5) : .clear, radius: 4, y: 1)
    }

    private var chatList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NotchTheme.secondary)
                TextField("Search conversations", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(NotchTheme.text)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(NotchTheme.separator, lineWidth: 0.5)
            }
            .padding(6)

            if store.filteredChats.isEmpty {
                ContentUnavailableView("No conversations", systemImage: "bubble.left.and.bubble.right", description: Text("Try a different search."))
                    .foregroundStyle(NotchTheme.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.filteredChats) { chat in
                            ChatRow(chat: chat) { store.select(chat) }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.never)
            }
        }
    }

    private var conversation: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.selectedMessages) { message in
                            MessageBubble(message: message) {
                                withAnimation(.easeOut(duration: 0.16)) { viewedMediaMessageID = message.id }
                            }
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 5)
                }
                .scrollIndicators(.never)
                .onChange(of: store.selectedMessages.count) {
                    guard let id = store.selectedMessages.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) }
                }
            }

            Divider().overlay(NotchTheme.separator)
            HStack(alignment: .bottom, spacing: 5) {
                TextField("Message", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .font(.system(size: 11))
                    .foregroundStyle(NotchTheme.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(NotchTheme.separator, lineWidth: 0.5)
                    }
                    .focused($composerFocused)
                    .onSubmit(sendDraft)

                Button(action: sendDraft) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NotchTheme.secondary : .black)
                        .frame(width: 28, height: 28)
                        .background(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NotchTheme.raised : NotchTheme.telegram, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
                .help("Send message")
            }
            .padding(5)
        }
    }

    private func sendDraft() {
        let sent = draft
        guard !sent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        draft = ""
        store.sendMessage(sent)
    }
}

private struct ChatRow: View {
    let chat: Chat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 1) {
                Text(chat.title)
                    .font(.system(size: 11, weight: chat.unreadCount > 0 ? .bold : .semibold))
                    .foregroundStyle(NotchTheme.text)
                    .lineLimit(1)
                Text(chat.preview)
                    .font(.system(size: 10))
                    .foregroundStyle(NotchTheme.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchRowButtonStyle())
    }
}

private struct MessageBubble: View {
    let message: Message
    let openMedia: () -> Void

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 28) }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(message.isOutgoing ? "You" : message.sender)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(message.isOutgoing ? Color.black.opacity(0.62) : NotchTheme.telegram)
                    if message.isOutgoing {
                        Label(message.isRead ? "Read" : "Sent", systemImage: message.isRead ? "checkmark.circle.fill" : "checkmark")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.black.opacity(message.isRead ? 0.72 : 0.5))
                            .help(message.isRead ? "Read" : "Sent")
                    }
                }
                if let media = message.media {
                    MediaPreview(media: media, outgoing: message.isOutgoing, action: openMedia)
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(size: 11))
                        .foregroundStyle(message.isOutgoing ? Color.black.opacity(0.88) : NotchTheme.text)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                message.isOutgoing ? AnyShapeStyle(NotchTheme.telegram) : AnyShapeStyle(.thinMaterial),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                if !message.isOutgoing {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(NotchTheme.separator, lineWidth: 0.5)
                }
            }
            if !message.isOutgoing { Spacer(minLength: 28) }
        }
    }
}

private struct MediaPreview: View {
    let media: MessageMedia
    let outgoing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if let path = media.thumbnailPath ?? (media.kind == .photo ? media.localPath : nil),
                   let image = NSImage(contentsOfFile: path) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(outgoing ? Color.black.opacity(0.12) : NotchTheme.raised)
                    ProgressView()
                        .controlSize(.small)
                        .tint(outgoing ? .black.opacity(0.7) : NotchTheme.text)
                }

                if media.kind == .video {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.58), in: Circle())
                }
            }
            .frame(width: 174, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(media.kind == .video ? "Play video" : "View photo")
        .accessibilityLabel(media.kind == .video ? "Open video" : "Open photo")
    }
}

private struct MediaViewer: View {
    let media: MessageMedia
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.5))

            Group {
                if media.kind == .photo, let path = media.localPath, let image = NSImage(contentsOfFile: path) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                } else if media.kind == .video, let path = media.localPath {
                    InlineVideoPlayer(url: URL(fileURLWithPath: path))
                        .padding(6)
                } else {
                    VStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Downloading media…")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(NotchTheme.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .buttonStyle(NotchIconButtonStyle())
            .padding(7)
            .help("Close media")
            .keyboardShortcut(.escape, modifiers: [])
        }
    }
}

private struct InlineVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .onAppear { player.play() }
            .onDisappear { player.pause() }
            .onChange(of: url) { _, newURL in
                player.replaceCurrentItem(with: AVPlayerItem(url: newURL))
                player.play()
            }
    }
}

private struct NotchIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? NotchTheme.text : NotchTheme.secondary)
            .background(configuration.isPressed ? NotchTheme.raised : .clear, in: Circle())
            .contentShape(Circle())
    }
}

private struct NotchRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? NotchTheme.raised : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

