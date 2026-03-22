//
import SwiftUI

struct DraftImageStrip: View {
    let images: [ChatImageAttachment]
    let onRemove: (ChatImageAttachment) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(images) { image in
                    ZStack(alignment: .topTrailing) {
                        ChatAttachmentThumbnail(image: image)
                            .frame(width: 72, height: 72)

                        Button {
                            onRemove(image)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.white, .black.opacity(0.65))
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                    }
                }
            }
        }
        .frame(height: 80)
    }
}

struct MessageImageStrip: View {
    let images: [ChatImageAttachment]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(images) { image in
                    ChatAttachmentThumbnail(image: image)
                        .frame(width: 140, height: 140)
                }
            }
        }
        .frame(height: 148)
    }
}

struct ChatAttachmentThumbnail: View {
    let image: ChatImageAttachment
    private let cornerRadius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.black.opacity(0.08))
            .overlay {
                thumbnailContent
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let platformImage = PlatformImage.chatAttachment(at: image.url) {
            Image(platformImage: platformImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        else {
            VStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.title2)
                Text(image.filename)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
