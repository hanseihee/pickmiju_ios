import SwiftUI
import AuthenticationServices

struct LoginView: View {
    let authService: AuthService

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App Icon
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("pickmiju")
                .font(.system(size: 28, weight: .bold))
            Text("미국 주식 실시간 시세")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 12) {
                // Google Sign In
                Button {
                    Task {
                        try? await authService.signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 20))
                        Text("Google로 로그인")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Apple Sign In
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Skip
                Button {
                    // Just dismiss - user stays anonymous
                } label: {
                    Text("로그인 없이 사용하기")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            Task {
                try? await authService.signInWithApple(credential: credential)
            }
        case .failure(let error):
            print("[Auth] Apple sign in error: \(error)")
        }
    }
}

// MARK: - Profile View (for Settings tab)

struct ProfileView: View {
    let authService: AuthService
    @State private var showDeleteAlert = false

    var body: some View {
        if authService.isLoggedIn {
            loggedInView
        } else {
            loggedOutView
        }
    }

    private var loggedInView: some View {
        Section {
            HStack(spacing: 14) {
                AsyncImage(url: authService.avatarURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(authService.displayName)
                        .font(.system(size: 15, weight: .semibold))
                    Text(authService.email)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            Button("로그아웃") {
                Task { await authService.signOut() }
            }
            .foregroundStyle(.red)
        } header: {
            Text("계정")
        }
    }

    private var loggedOutView: some View {
        Section {
            Button {
                Task { try? await authService.signInWithGoogle() }
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                    Text("Google로 로그인")
                }
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                if case .success(let auth) = result,
                   let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                    Task { try? await authService.signInWithApple(credential: credential) }
                }
            }
            .frame(height: 44)
        } header: {
            Text("로그인하면 워치리스트가 기기 간 동기화됩니다")
        }
    }
}
