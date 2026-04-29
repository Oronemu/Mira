import SwiftUI
import CoreKit
import DesignSystem

public struct EntryRowCard: View {
    private let entry: EntrySnapshot
    private let namespace: Namespace.ID?

    public init(entry: EntrySnapshot, namespace: Namespace.ID? = nil) {
        self.entry = entry
        self.namespace = namespace
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MoodAccent(level: entry.mood?.rawValue)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                header
                body_text
                if !entry.photos.isEmpty { photosRow }
                if !entry.tags.isEmpty { tagsRow }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background {
            let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
            if let level = entry.mood?.rawValue {
                shape.fill(MiraPalette.mood(level: level).opacity(0.08))
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 14, x: 0, y: 6)
        .transitionSource(id: entry.id, in: namespace)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(entry.createdAt.formatted(
                .dateTime.day().month(.abbreviated).hour().minute()
            ))
            .eyebrowStyle()
            Spacer()
            if let mood = entry.mood {
                Text(mood.emoji)
                    .font(.system(size: 15))
                    .accessibilityLabel(mood.label)
            }
        }
    }

    private var body_text: some View {
        Text(entry.content)
            .font(MiraTypography.entryBody)
            .foregroundStyle(MiraPalette.primaryText)
            .lineSpacing(3)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var tagsRow: some View {
        HStack(spacing: 6) {
            ForEach(entry.tags.prefix(4), id: \.self) { tag in
                TagPill(tag, tintLevel: entry.mood?.rawValue)
            }
            if entry.tags.count > 4 {
                Text("+\(entry.tags.count - 4)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MiraPalette.secondaryText)
            }
        }
    }

    private var photosRow: some View {
        HStack(spacing: 5) {
            ForEach(entry.photos.prefix(4)) { photo in
                MiniPhotoThumb(photo: photo)
            }
            if entry.photos.count > 4 {
                Text("+\(entry.photos.count - 4)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MiraPalette.secondaryText)
            }
        }
    }
}

/// Tiny 26×26 thumbnail shown on entry cards so you can tell which entries
/// have photos attached without opening them. Reads via the shared
/// `PhotoStoring` environment, matching the full-size strip's loading path.
private struct MiniPhotoThumb: View {
    @Environment(\.photoStoring) private var photoStore
    let photo: PhotoAssetSnapshot

    @State private var image: Image?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        Group {
            if let image {
                image.resizable().scaledToFill()
            } else {
                Rectangle().fill(MiraPalette.secondaryBackground)
            }
        }
        .frame(width: 26, height: 26)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(MiraPalette.primaryText.opacity(0.08), lineWidth: 0.5)
        }
        .task(id: photo.id) { await loadImage() }
    }

    private func loadImage() async {
        do {
            let data = try await photoStore.read(relativePath: photo.relativePath)
            if let uiImage = UIImage(data: data) {
                image = Image(uiImage: uiImage)
            }
        } catch {
            // Silent failure — thumb stays as a plain swatch.
        }
    }
}

private struct TagPill: View {
    let text: String
    let tintLevel: Int?

    init(_ text: String, tintLevel: Int?) {
        self.text = text
        self.tintLevel = tintLevel
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .foregroundStyle(foreground)
            .background(Capsule().fill(background))
    }

    private var foreground: Color {
        MiraPalette.primaryText.opacity(0.82)
    }

    private var background: Color {
        if let tintLevel {
            return MiraPalette.mood(level: tintLevel).opacity(0.18)
        }
        return MiraPalette.secondaryBackground
    }
}

private extension View {
    /// Attaches `matchedTransitionSource` only when a namespace is provided,
    /// so the card remains usable outside of a navigation-transition context.
    @ViewBuilder
    func transitionSource(id: UUID, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
