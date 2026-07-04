import SwiftUI

struct LicenseView: View {
  var store: SettingsStore
  private let viewModel: CheckForUpdatesViewModel = .shared
  @State private var isPro = false
  @State private var promoHidden = false

  private static let gitHubURL = URL(string: "https://github.com/chikingsley/toy-local/")

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        licenseCard
        linkPills
        if !promoHidden {
          promoCard
        }
        maintenanceCard
      }
      .padding(24)
      .frame(maxWidth: 620)
      .frame(maxWidth: .infinity)
    }
    .background(Color(nsColor: .windowBackgroundColor))
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
          .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        Image(systemName: "info.circle")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .help("ToyLocal Pro unlocks cloud models, mode sync, and priority updates while local dictation stays available.")
      }

      Text(isPro ? "Your Pro license is active" : "Your Pro trial has ended")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.top, 3)

      Capsule()
        .fill(Color.accentColor)
        .frame(height: 8)
        .padding(.top, 18)

      HStack(spacing: 8) {
        Button(isPro ? "License Active" : "Activate License") {
          isPro = true
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Button("Purchase") {
          isPro = true
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)

        Spacer()

        Text("25% off")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.secondary)

        Text("LOCAL25")
          .font(.system(size: 12, weight: .bold))
          .padding(.horizontal, 12)
          .frame(height: 26)
          .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
      }
      .padding(8)
      .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
      .padding(.top, 20)
    }
    .padding(16)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
  }

  private var linkPills: some View {
    HStack(spacing: 8) {
      LicenseLinkPill(icon: "point.topleft.down.curvedto.point.bottomright.up", label: "Roadmap")
      LicenseLinkPill(icon: "envelope.fill", label: "Email", iconBackground: .blue)
      LicenseLinkPill(icon: "safari.fill", label: "Website", url: Self.gitHubURL)
      LicenseLinkPill(icon: "bubble.left.and.bubble.right.fill", label: "Discord")
      LicenseLinkPill(icon: "xmark", label: "X")
    }
    .frame(maxWidth: .infinity)
  }

  private var promoCard: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: "cloud.fill")
        .font(.system(size: 27, weight: .semibold))
        .foregroundStyle(Color.accentColor)
        .frame(width: 56, height: 56)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))

      VStack(alignment: .leading, spacing: 4) {
        Text("Enjoying ToyLocal?")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
        Text("Use Pro to keep local dictation plus hosted models when you need extra speed or availability.")
          .font(.system(size: 14, weight: .semibold))
          .fixedSize(horizontal: false, vertical: true)
        Button("See plans") {}
          .buttonStyle(.plain)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Color.accentColor)
      }

      Spacer()

      Button {
        promoHidden = true
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .help("Dismiss")
    }
    .padding(16)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
  }

  private var maintenanceCard: some View {
    HStack(spacing: 12) {
      Label("Version", systemImage: "shippingbox")
      Spacer()
      Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
        .foregroundStyle(.secondary)
      Button("Check for Updates") {
        viewModel.checkForUpdates()
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .font(.system(size: 13))
    .padding(14)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
  }
}

private struct LicenseLinkPill: View {
  let icon: String
  let label: String
  var iconBackground: Color?
  var url: URL?

  var body: some View {
    Group {
      if let url {
        Link(destination: url) {
          content
        }
      } else {
        Button {} label: {
          content
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var content: some View {
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
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
  }
}

#Preview {
  LicenseView(store: AppPreviewState.makeStore().settings)
    .frame(width: 660, height: 420)
}
