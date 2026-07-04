import SwiftUI

enum HistoryMetrics {
  static let animationDuration = 0.18
  static let panePadding: CGFloat = 24
  static let rowSpacing: CGFloat = 8
  static let sectionSpacing: CGFloat = 18
  static let cardRadius: CGFloat = 14
  static let iconSize: CGFloat = 26
}

enum HistoryStyle {
  static let accentGreen = TLTheme.accentGreen
  static let playbackBlue = Color.accentColor
  static let cardFill = Color.primary.opacity(0.075)
}

extension View {
  func historyBorderedCard(
    fill: Color = HistoryStyle.cardFill,
    cornerRadius: CGFloat = 11
  ) -> some View {
    background(fill, in: RoundedRectangle(cornerRadius: cornerRadius))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .strokeBorder(TLTheme.borderStroke, lineWidth: 1)
      )
  }
}

struct HistoryEditableTitle: View {
  let title: String
  @Binding var draft: String
  let isEditing: Bool
  let beginEditing: () -> Void
  let commit: () -> Void
  let cancel: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      if isEditing {
        TextField("Title", text: $draft)
          .textFieldStyle(.plain)
          .font(.system(size: 13, weight: .semibold))
          .frame(width: 190)
          .padding(.horizontal, 8)
          .frame(height: 26)
          .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
        TLIconButton(
          systemName: "checkmark",
          tileSize: 22,
          hitSize: 28,
          foreground: HistoryStyle.accentGreen,
          help: "Save title",
          action: commit
        )
        TLIconButton(
          systemName: "xmark",
          tileSize: 22,
          hitSize: 28,
          help: "Cancel rename",
          action: cancel
        )
      } else {
        Button(action: beginEditing) {
          Text(title)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct HistoryHeaderActions: View {
  let copied: Bool
  let openDetails: () -> Void
  let copy: () -> Void
  let delete: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      TLIconButton(systemName: "info.circle", tileSize: 22, hitSize: 28, help: "Recording details", action: openDetails)
      TLIconButton(
        systemName: copied ? "checkmark" : "doc.on.doc",
        tileSize: 22,
        hitSize: 28,
        foreground: copied ? HistoryStyle.accentGreen : nil,
        help: copied ? "Copied" : "Copy transcript",
        action: copy
      )
      TLIconButton(
        systemName: "trash",
        tileSize: 22,
        hitSize: 28,
        foreground: .red.opacity(0.9),
        help: "Delete",
        action: delete
      )
    }
    .font(.system(size: 12, weight: .semibold))
    .foregroundStyle(.secondary)
  }
}

struct HistoryRow: View {
  let item: HistoryItem
  let open: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: open) {
      historyCard
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }

  private var historyCard: some View {
    HStack(alignment: .top, spacing: 12) {
      HistoryAppIcon(app: item.app)
      VStack(alignment: .leading, spacing: 7) {
        HStack {
          Text(item.title)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
          Text(item.timeLabel)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
          Spacer()
          if let speakers = item.speakers {
            Text("\(speakers) speakers")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.secondary)
          }
        }
        Text(item.preview)
          .font(.system(size: 13))
          .lineLimit(2)
        HStack(spacing: 8) {
          TLKeyChip(item.app.rawValue)
          TLKeyChip(item.duration)
          TLKeyChip(item.mode)
        }
      }
    }
    .padding(14)
    .historyBorderedCard(
      fill: .primary.opacity(hovering ? 0.11 : 0.075),
      cornerRadius: HistoryMetrics.cardRadius
    )
  }
}

struct HistoryAppIcon: View {
  let app: HistoryApp
  var size: CGFloat = HistoryMetrics.iconSize

  var body: some View {
    Image(systemName: app.icon)
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(app.tint.color.gradient, in: RoundedRectangle(cornerRadius: 7))
  }
}

struct HistoryEmptyState: View {
  let systemName: String
  let title: String
  let message: String

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: systemName)
        .font(.system(size: 24, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(width: 44, height: 44)
        .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
      Text(title)
        .font(.system(size: 14, weight: .semibold))
      Text(message)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 260)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(HistoryMetrics.panePadding)
  }
}
