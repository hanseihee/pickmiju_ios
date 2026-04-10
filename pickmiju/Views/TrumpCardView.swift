import SwiftUI

struct TrumpCardView: View {
    let truth: TrumpTruth
    @Environment(\.openURL) private var openURL
    @State private var showOriginal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if truth.hasText { contentSection }
            if truth.hasMedia { mediaSection }
            footer
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image("TrumpAvatar")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Donald J. Trump")
                        .font(.system(size: 15, weight: .bold))

                    if truth.isRetruth {
                        Text("RT")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text("@realDonaldTrump")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(truth.relativeTime)
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let ko = truth.content_ko, !ko.isEmpty {
                Text(ko)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .foregroundStyle(.primary)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showOriginal.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(showOriginal ? "원문 숨기기" : "원문 보기")
                        Image(systemName: showOriginal ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)

                if showOriginal {
                    Divider()
                        .padding(.vertical, 8)

                    Text(truth.content)
                        .font(.system(size: 13))
                        .lineSpacing(3)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(truth.content)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Media

    private var mediaSection: some View {
        VStack(spacing: 8) {
            ForEach(truth.media, id: \.self) { urlString in
                if urlString.hasSuffix(".mp4") {
                    videoThumbnail(urlString)
                } else {
                    AsyncImage(url: URL(string: urlString)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 400)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            imagePlaceholder(systemName: "photo.badge.exclamationmark")
                        case .empty:
                            imagePlaceholder(systemName: "photo")
                                .overlay(ProgressView())
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }

    private func videoThumbnail(_ urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) {
                openURL(url)
            }
        } label: {
            ZStack {
                imagePlaceholder(systemName: "video")
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 4)
            }
        }
        .buttonStyle(.plain)
    }

    private func imagePlaceholder(systemName: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.tertiarySystemFill))
            .frame(height: 200)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
            )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            HStack(spacing: 16) {
                Label(formatCount(truth.replies_count), systemImage: "bubble.right")
                Label(formatCount(truth.reblogs_count), systemImage: "arrow.2.squarepath")
                Label(formatCount(truth.favourites_count), systemImage: "heart")
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)

            Spacer()

            if let url = URL(string: truth.url) {
                Link(destination: url) {
                    HStack(spacing: 3) {
                        Text("Truth Social")
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.cyan)
                }
            }
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}
