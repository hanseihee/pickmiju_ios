import Foundation
import Supabase
import Realtime

@Observable
final class ChatService {
    var messages: [ChatMessage] = []
    var isLoading = false
    var nickname: String
    var onlineCount = 1
    var unreadCount = 0

    private var channel: RealtimeChannelV2?
    private var presenceChannel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private let deviceId = DeviceIdentity.deviceId
    var isVisible = false
    private var presenceSubscription: RealtimeSubscription?

    init() {
        nickname = NicknameGenerator.savedNickname ?? NicknameGenerator.generate()
        NicknameGenerator.save(nickname)
    }

    deinit {
        listenTask?.cancel()
    }

    // MARK: - Load Nickname from Server

    /// Load existing nickname from chat_users table (same as web logic)
    /// Called on connect — checks if this device already has a registered nickname
    private func loadNicknameFromServer() async {
        struct UserRow: Codable { let nickname: String }

        do {
            let row: UserRow = try await supabase
                .from("chat_users")
                .select("nickname")
                .eq("user_hash", value: deviceId)
                .single()
                .execute()
                .value

            if !row.nickname.isEmpty {
                nickname = row.nickname
                NicknameGenerator.save(row.nickname)
            }
        } catch {
            // No existing record — keep current local nickname and register it
            try? await supabase
                .from("chat_users")
                .upsert([
                    "user_hash": deviceId,
                    "nickname": nickname,
                ])
                .execute()
        }
    }

    // MARK: - Connect

    func connect() {
        guard channel == nil else { return }

        Task {
            await loadNicknameFromServer()
            await fetchMessages()
            await subscribeToMessages()
            await subscribeToPresence()
        }
    }

    func disconnect() {
        listenTask?.cancel()
        listenTask = nil

        Task {
            if let channel {
                await supabase.realtimeV2.removeChannel(channel)
            }
            if let presenceChannel {
                await supabase.realtimeV2.removeChannel(presenceChannel)
            }
        }
        channel = nil
        presenceChannel = nil
    }

    // MARK: - Fetch Messages

    private func fetchMessages() async {
        isLoading = true
        do {
            let response: [ChatMessage] = try await supabase
                .from("chat_messages")
                .select()
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            messages = response.reversed()
        } catch {
            print("[Chat] Fetch error: \(error)")
        }
        isLoading = false
    }

    // MARK: - Send Message

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let payload: [String: String] = [
            "nickname": nickname,
            "message": trimmed,
            "user_hash": deviceId,
        ]

        do {
            try await supabase
                .from("chat_messages")
                .insert(payload)
                .execute()
        } catch {
            print("[Chat] Send error: \(error)")
        }
    }

    // MARK: - Realtime Subscription

    private func subscribeToMessages() async {
        let ch = supabase.realtimeV2.channel("chat_messages_ios")

        let insertions = ch.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "chat_messages"
        )

        await ch.subscribe()
        channel = ch

        listenTask = Task {
            for await insertion in insertions {
                guard !Task.isCancelled else { break }
                do {
                    let msg = try insertion.decodeRecord(as: ChatMessage.self, decoder: JSONDecoder())
                    messages.append(msg)

                    if !isVisible && msg.user_hash != deviceId {
                        unreadCount += 1
                    }
                } catch {
                    print("[Chat] Decode error: \(error)")
                }
            }
        }
    }

    // MARK: - Presence

    /// Tracks known presence keys to count online users
    private var presenceKeys: Set<String> = []

    private func subscribeToPresence() async {
        // Use same channel name as web ("chat_presence") to share presence state
        let myDeviceId = deviceId
        let ch = supabase.realtimeV2.channel("chat_presence") {
            $0.presence.key = myDeviceId
        }

        // joins/leaves give us who joined and left
        presenceSubscription = ch.onPresenceChange { [weak self] (action: any PresenceAction) in
            guard let self else { return }
            for key in action.joins.keys {
                self.presenceKeys.insert(key)
            }
            for key in action.leaves.keys {
                self.presenceKeys.remove(key)
            }
            self.onlineCount = max(1, self.presenceKeys.count)
        }

        await ch.subscribe()
        presenceChannel = ch

        // Track self
        let trackState: JSONObject = [
            "nickname": .string(nickname),
            "user_hash": .string(myDeviceId),
            "online_at": .string(ISO8601DateFormatter().string(from: Date())),
        ]
        await ch.track(state: trackState)

        // Add self to known keys
        presenceKeys.insert(myDeviceId)
        onlineCount = max(1, presenceKeys.count)
    }

    // MARK: - Nickname

    func updateNickname(_ newNickname: String) async throws {
        let trimmed = newNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Check uniqueness against chat_users table
        struct UserRow: Codable { let user_hash: String }
        let existing: [UserRow] = try await supabase
            .from("chat_users")
            .select("user_hash")
            .eq("nickname", value: trimmed)
            .neq("user_hash", value: deviceId)
            .execute()
            .value

        guard existing.isEmpty else {
            throw ChatError.nicknameTaken
        }

        // Upsert
        try await supabase
            .from("chat_users")
            .upsert([
                "user_hash": deviceId,
                "nickname": trimmed,
                "updated_at": ISO8601DateFormatter().string(from: Date()),
            ])
            .execute()

        nickname = trimmed
        NicknameGenerator.save(trimmed)
    }

    func clearUnread() {
        unreadCount = 0
    }
}

// MARK: - Errors

enum ChatError: LocalizedError {
    case nicknameTaken

    var errorDescription: String? {
        switch self {
        case .nicknameTaken: return "이미 사용 중인 닉네임입니다"
        }
    }
}
