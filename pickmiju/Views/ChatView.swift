import SwiftUI

struct ChatView: View {
    @State var chatService: ChatService
    @State private var inputText = ""
    @State private var showNicknameSheet = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(chatService.messages) { msg in
                            MessageBubble(
                                message: msg,
                                isMe: msg.isFromSameUser
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .defaultScrollAnchor(.bottom)
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        Divider()
                        inputBar
                    }
                    .background(.bar)
                }
                .onTapGesture {
                    isInputFocused = false
                }
                .onChange(of: chatService.messages.count) {
                    scrollToBottom(scrollProxy)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                    let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
                    withAnimation(.easeOut(duration: duration)) {
                        scrollToBottom(scrollProxy)
                    }
                }
            }
            .navigationTitle("채팅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("\(chatService.onlineCount)명 접속중")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNicknameSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 14))
                            Text(displayNickname)
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showNicknameSheet) {
                NicknameEditSheet(chatService: chatService)
                    .presentationDetents([.height(200)])
            }
            .onAppear {
                chatService.isVisible = true
                chatService.clearUnread()
                chatService.connect()
            }
            .onDisappear {
                chatService.isVisible = false
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = chatService.messages.last {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private var displayNickname: String {
        let nick = chatService.nickname
        if nick.count > 8 {
            return String(nick.prefix(8)) + "..."
        }
        return nick
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("메시지 입력", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onSubmit {
                    sendCurrentMessage()
                }

            Button {
                sendCurrentMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sendCurrentMessage() {
        let text = inputText
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        inputText = ""
        Task { await chatService.sendMessage(text) }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let isMe: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isMe { Spacer(minLength: 60) }

            if !isMe {
                Text(String(message.nickname.prefix(1)))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(avatarColor)
                    .clipShape(Circle())
            }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                if !isMe {
                    Text(message.nickname)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .bottom, spacing: 4) {
                    if isMe {
                        Text(message.timeString)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }

                    Text(message.message)
                        .font(.system(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isMe ? Color.blue : Color(.secondarySystemBackground))
                        .foregroundStyle(isMe ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    if !isMe {
                        Text(message.timeString)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if !isMe { Spacer(minLength: 60) }
        }
        .padding(.vertical, 2)
    }

    private var avatarColor: Color {
        // Deterministic color from nickname hash
        let hash = abs(message.nickname.hashValue)
        let colors: [Color] = [.blue, .purple, .orange, .pink, .teal, .indigo, .mint, .cyan]
        return colors[hash % colors.count]
    }
}

// MARK: - Nickname Edit Sheet

private struct NicknameEditSheet: View {
    let chatService: ChatService
    @Environment(\.dismiss) private var dismiss
    @State private var newNickname = ""
    @State private var error: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("닉네임", text: $newNickname)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                if let error {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }

                Button {
                    save()
                } label: {
                    Text("변경")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isSaving || newNickname.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("닉네임 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
        .onAppear {
            newNickname = chatService.nickname
        }
    }

    private func save() {
        isSaving = true
        error = nil
        Task {
            do {
                try await chatService.updateNickname(newNickname)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }
}
