import SwiftUI

struct PrototypeLicensePane: View {
  @State private var isPro = false
  @State private var promoHidden = false

  var body: some View {
    VStack(spacing: 0) {
      TLHeader {
        EmptyView()
      } trailing: {
        EmptyView()
      }

      VStack(alignment: .leading, spacing: 18) {
        licenseCard
        linkPills
        Spacer(minLength: 20)
        if !promoHidden {
          promoCard
        }
      }
      .padding(EdgeInsets(top: 18, leading: 24, bottom: 24, trailing: 24))
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }

  private var licenseCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 8) {
        Text("ToyLocal")
          .font(.system(size: 14, weight: .semibold))
        Text("PRO")
          .font(.system(size: 10, weight: .bold))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(TLTheme.chipSurface, in: RoundedRectangle(cornerRadius: 4))
        TLInfoHint("ToyLocal Pro unlocks cloud models, mode sync, and priority updates while keeping local dictation available.")
      }

      Text(isPro ? "Your Pro license is active" : "Your Pro trial has ended")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.top, 3)

      Capsule()
        .fill(TLTheme.accentGreen)
        .frame(height: 8)
        .padding(.top, 18)

      HStack(spacing: 8) {
        Button {
          isPro = true
        } label: {
          Text(isPro ? "License Active" : "Activate License")
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
              isPro ? Color.primary.opacity(0.10) : Color.clear,
              in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.primary.opacity(isPro ? 0.06 : 0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)

        Button {
          isPro = true
        } label: {
          Text("Purchase")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(TLTheme.accentGreen, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)

        Spacer()

        Text("25% off")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.secondary)

        Text("LOCAL25")
          .font(.system(size: 12, weight: .bold))
          .padding(.horizontal, 12)
          .frame(height: 26)
          .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
      }
      .padding(8)
      .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
      .padding(.top, 20)
    }
    .padding(16)
    .background(TLTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14))
  }

  private var linkPills: some View {
    HStack(spacing: 8) {
      PrototypeLicenseLinkPill(icon: "point.topleft.down.curvedto.point.bottomright.up", label: "Roadmap")
      PrototypeLicenseLinkPill(icon: "envelope.fill", label: "Email", iconBackground: Color.blue)
      PrototypeLicenseLinkPill(icon: "safari.fill", label: "Website")
      PrototypeLicenseLinkPill(icon: "bubble.left.and.bubble.right.fill", label: "Discord")
      PrototypeLicenseLinkPill(icon: "xmark", label: "X")
    }
    .frame(maxWidth: .infinity)
  }

  private var promoCard: some View {
    HStack(alignment: .top, spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 14)
          .fill(Color.black.opacity(0.14))
        Image(systemName: "cloud.fill")
          .font(.system(size: 27, weight: .semibold))
          .foregroundStyle(TLTheme.accentGreen)
      }
      .frame(width: 56, height: 56)

      VStack(alignment: .leading, spacing: 4) {
        Text("Enjoying ToyLocal?")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
        Text("Use Pro to keep local dictation plus hosted models when you need extra speed or availability.")
          .font(.system(size: 14, weight: .semibold))
          .fixedSize(horizontal: false, vertical: true)
        Button("See plans") {}
          .font(.system(size: 13, weight: .semibold))
          .buttonStyle(.plain)
          .foregroundStyle(TLTheme.accentGreen)
      }

      Spacer()

      TLIconButton(
        systemName: "xmark",
        tileSize: 22,
        hitSize: 28,
        help: "Dismiss",
        action: { promoHidden = true }
      )
    }
    .padding(16)
    .background(TLTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(TLTheme.borderStroke, lineWidth: 1)
    )
  }
}

private struct PrototypeLicenseLinkPill: View {
  let icon: String
  let label: String
  var iconBackground: Color?

  @State private var hovering = false

  var body: some View {
    Button {
    } label: {
      HStack(spacing: 7) {
        ZStack {
          if let iconBackground {
            RoundedRectangle(cornerRadius: 4)
              .fill(iconBackground)
          }
          Image(systemName: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(iconBackground == nil ? Color.primary : Color.white)
        }
        .frame(width: 16, height: 16)

        Text(label)
          .font(.system(size: 13, weight: .semibold))
      }
      .padding(.horizontal, 12)
      .frame(height: 32)
      .background(
        hovering ? TLTheme.hoverFill : TLTheme.cardSurface,
        in: RoundedRectangle(cornerRadius: 8)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(TLTheme.borderStroke, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

#Preview("License") {
  TLFloatingHost {
    PrototypeLicensePane()
      .frame(width: 620, height: 700)
      .background(TLTheme.windowBackground)
  }
}
