import Foundation
import Supabase
import Auth
import AuthenticationServices

@Observable
final class AuthService {
    var user: User?
    var isLoading = true
    var isLoggedIn: Bool { user != nil }

    private var authListener: Task<Void, Never>?

    init() {
        startListening()
    }

    deinit {
        authListener?.cancel()
    }

    // MARK: - Session Management

    private func startListening() {
        // Get initial session
        Task {
            do {
                let session = try await supabase.auth.session
                self.user = session.user
            } catch {
                self.user = nil
            }
            self.isLoading = false
        }

        // Listen for auth state changes
        authListener = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                guard !Task.isCancelled else { break }
                if event == .signedIn || event == .tokenRefreshed {
                    self.user = session?.user
                } else if event == .signedOut {
                    self.user = nil
                }
            }
        }
    }

    // MARK: - Google Sign In (via Supabase OAuth + ASWebAuthenticationSession)

    func signInWithGoogle() async throws {
        try await supabase.auth.signInWithOAuth(
            provider: Provider.google,
            redirectTo: SupabaseConfig.redirectURL
        )
    }

    // MARK: - Apple Sign In

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let idTokenData = credential.identityToken,
              let idToken = String(data: idTokenData, encoding: .utf8) else {
            throw AuthServiceError.invalidCredential
        }

        try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken
            )
        )
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await supabase.auth.signOut()
            user = nil
        } catch {
            print("[Auth] Sign out error: \(error)")
        }
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard user != nil else {
            throw AuthServiceError.notLoggedIn
        }

        // Supabase RPC로 사용자 데이터 및 계정 삭제
        try await supabase.rpc("delete_user").execute()

        // 로컬 세션 정리
        try await supabase.auth.signOut()
        user = nil
    }

    // MARK: - Handle URL Callback

    func handleURL(_ url: URL) async {
        do {
            try await supabase.auth.session(from: url)
        } catch {
            print("[Auth] URL callback error: \(error)")
        }
    }

    // MARK: - User Info

    var displayName: String {
        if let name = user?.userMetadata["full_name"] {
            if case .string(let str) = name { return str }
        }
        return user?.email ?? "사용자"
    }

    var email: String {
        user?.email ?? ""
    }

    var avatarURL: URL? {
        if let urlValue = user?.userMetadata["avatar_url"],
           case .string(let urlString) = urlValue {
            return URL(string: urlString)
        }
        return nil
    }
}

// MARK: - Auth Errors

enum AuthServiceError: LocalizedError {
    case invalidCredential
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "유효하지 않은 인증 정보입니다"
        case .notLoggedIn: return "로그인이 필요합니다"
        }
    }
}
