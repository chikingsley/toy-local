import SwiftUI

struct LicensePane: View {
  @State private var isPro = false
  @State private var promoHidden = false

  var body: some View {
    VStack(spacing: LicensePaneMetrics.stackSpacing) {
      TLHeader {
        EmptyView()
      } trailing: {
        EmptyView()
      }

      VStack(alignment: .leading, spacing: LicensePaneMetrics.contentSpacing) {
        licenseCard
        linkPills
        Spacer(minLength: LicensePaneMetrics.contentSpacerMinLength)
        if !promoHidden {
          promoCard
        }
      }
      .padding(LicensePaneMetrics.contentInsets)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }

  private var licenseCard: some View {
    VStack(alignment: .leading, spacing: LicensePaneMetrics.stackSpacing) {
      HStack(spacing: LicensePaneMetrics.brandSpacing) {
        Text(LicensePaneCopy.productName)
          .font(.system(size: LicensePaneMetrics.productFontSize, weight: .semibold))
        Text(LicensePaneCopy.proBadge)
          .font(.system(size: LicensePaneMetrics.badgeFontSize, weight: .bold))
          .padding(.horizontal, LicensePaneMetrics.badgeHorizontalPadding)
          .padding(.vertical, LicensePaneMetrics.badgeVerticalPadding)
          .background(TLTheme.chipSurface, in: RoundedRectangle(cornerRadius: LicensePaneMetrics.badgeCornerRadius))
        TLInfoHint(LicensePaneCopy.proHint)
      }

      Text(isPro ? LicensePaneCopy.activeStatus : LicensePaneCopy.trialEndedStatus)
        .font(.system(size: LicensePaneMetrics.statusFontSize))
        .foregroundStyle(.secondary)
        .padding(.top, LicensePaneMetrics.statusTopPadding)

      Capsule()
        .fill(TLTheme.accentGreen)
        .frame(height: LicensePaneMetrics.progressHeight)
        .padding(.top, LicensePaneMetrics.progressTopPadding)

      HStack(spacing: LicensePaneMetrics.actionSpacing) {
        Button {
          isPro = true
        } label: {
          Text(isPro ? LicensePaneCopy.licenseActiveButton : LicensePaneCopy.activateButton)
            .font(.system(size: LicensePaneMetrics.buttonFontSize, weight: .semibold))
            .padding(.horizontal, LicensePaneMetrics.buttonHorizontalPadding)
            .frame(height: LicensePaneMetrics.buttonHeight)
            .background(
              isPro ? Color.primary.opacity(LicensePaneMetrics.activeButtonOpacity) : Color.clear,
              in: RoundedRectangle(cornerRadius: LicensePaneMetrics.buttonCornerRadius)
            )
            .overlay(
              RoundedRectangle(cornerRadius: LicensePaneMetrics.buttonCornerRadius)
                .strokeBorder(
                  Color.primary.opacity(isPro ? LicensePaneMetrics.activeButtonStrokeOpacity : LicensePaneMetrics.buttonStrokeOpacity),
                  lineWidth: LicensePaneMetrics.strokeWidth)
            )
        }
        .buttonStyle(.plain)

        Button {
          isPro = true
        } label: {
          Text(LicensePaneCopy.purchaseButton)
            .font(.system(size: LicensePaneMetrics.buttonFontSize, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, LicensePaneMetrics.buttonHorizontalPadding)
            .frame(height: LicensePaneMetrics.buttonHeight)
            .background(TLTheme.accentGreen, in: RoundedRectangle(cornerRadius: LicensePaneMetrics.buttonCornerRadius))
        }
        .buttonStyle(.plain)

        Spacer()

        Text(LicensePaneCopy.discountLabel)
          .font(.system(size: LicensePaneMetrics.discountFontSize, weight: .semibold))
          .foregroundStyle(.secondary)

        Text(LicensePaneCopy.discountCode)
          .font(.system(size: LicensePaneMetrics.codeFontSize, weight: .bold))
          .padding(.horizontal, LicensePaneMetrics.codeHorizontalPadding)
          .frame(height: LicensePaneMetrics.codeHeight)
          .background(
            Color.black.opacity(LicensePaneMetrics.codeBackgroundOpacity), in: RoundedRectangle(cornerRadius: LicensePaneMetrics.buttonCornerRadius))
      }
      .padding(LicensePaneMetrics.actionPadding)
      .background(
        Color.primary.opacity(LicensePaneMetrics.actionBackgroundOpacity), in: RoundedRectangle(cornerRadius: LicensePaneMetrics.actionCornerRadius)
      )
      .padding(.top, LicensePaneMetrics.actionTopPadding)
    }
    .padding(LicensePaneMetrics.cardPadding)
    .background(TLTheme.cardSurface, in: RoundedRectangle(cornerRadius: LicensePaneMetrics.cardCornerRadius))
  }

  private var linkPills: some View {
    HStack(spacing: LicensePaneMetrics.linkSpacing) {
      LicenseLinkPill(icon: LicensePaneIcons.roadmap, label: LicensePaneCopy.roadmapLabel)
      LicenseLinkPill(icon: LicensePaneIcons.email, label: LicensePaneCopy.emailLabel, iconBackground: Color.blue)
      LicenseLinkPill(icon: LicensePaneIcons.website, label: LicensePaneCopy.websiteLabel)
      LicenseLinkPill(icon: LicensePaneIcons.discord, label: LicensePaneCopy.discordLabel)
      LicenseLinkPill(icon: LicensePaneIcons.x, label: LicensePaneCopy.xLabel)
    }
    .frame(maxWidth: .infinity)
  }

  private var promoCard: some View {
    HStack(alignment: .top, spacing: LicensePaneMetrics.promoSpacing) {
      ZStack {
        RoundedRectangle(cornerRadius: LicensePaneMetrics.promoIconCornerRadius)
          .fill(Color.black.opacity(LicensePaneMetrics.promoIconBackgroundOpacity))
        Image(systemName: LicensePaneIcons.cloud)
          .font(.system(size: LicensePaneMetrics.promoIconFontSize, weight: .semibold))
          .foregroundStyle(TLTheme.accentGreen)
      }
      .frame(width: LicensePaneMetrics.promoIconSize, height: LicensePaneMetrics.promoIconSize)

      VStack(alignment: .leading, spacing: LicensePaneMetrics.promoTextSpacing) {
        Text(LicensePaneCopy.promoTitle)
          .font(.system(size: LicensePaneMetrics.promoTitleFontSize, weight: .semibold))
          .foregroundStyle(.secondary)
        Text(LicensePaneCopy.promoBody)
          .font(.system(size: LicensePaneMetrics.promoBodyFontSize, weight: .semibold))
          .fixedSize(horizontal: false, vertical: true)
        Button(LicensePaneCopy.seePlansButton) {}
          .font(.system(size: LicensePaneMetrics.seePlansFontSize, weight: .semibold))
          .buttonStyle(.plain)
          .foregroundStyle(TLTheme.accentGreen)
      }

      Spacer()

      TLIconButton(
        systemName: LicensePaneIcons.dismiss,
        tileSize: LicensePaneMetrics.dismissTileSize,
        hitSize: LicensePaneMetrics.dismissHitSize,
        help: LicensePaneCopy.dismissHelp
      ) {
        promoHidden = true
      }
    }
    .padding(LicensePaneMetrics.cardPadding)
    .background(TLTheme.cardSurface, in: RoundedRectangle(cornerRadius: LicensePaneMetrics.cardCornerRadius))
    .overlay(
      RoundedRectangle(cornerRadius: LicensePaneMetrics.cardCornerRadius)
        .strokeBorder(TLTheme.borderStroke, lineWidth: LicensePaneMetrics.strokeWidth)
    )
  }
}

private struct LicenseLinkPill: View {
  let icon: String
  let label: String
  var iconBackground: Color?

  @State private var hovering = false

  var body: some View {
    Button {
    } label: {
      HStack(spacing: LicensePaneMetrics.linkContentSpacing) {
        ZStack {
          if let iconBackground {
            RoundedRectangle(cornerRadius: LicensePaneMetrics.linkIconCornerRadius)
              .fill(iconBackground)
          }
          Image(systemName: icon)
            .font(.system(size: LicensePaneMetrics.linkIconFontSize, weight: .semibold))
            .foregroundStyle(iconBackground == nil ? Color.primary : Color.white)
        }
        .frame(width: LicensePaneMetrics.linkIconSize, height: LicensePaneMetrics.linkIconSize)

        Text(label)
          .font(.system(size: LicensePaneMetrics.linkFontSize, weight: .semibold))
      }
      .padding(.horizontal, LicensePaneMetrics.linkHorizontalPadding)
      .frame(height: LicensePaneMetrics.linkHeight)
      .background(
        hovering ? TLTheme.hoverFill : TLTheme.cardSurface,
        in: RoundedRectangle(cornerRadius: LicensePaneMetrics.linkCornerRadius)
      )
      .overlay(
        RoundedRectangle(cornerRadius: LicensePaneMetrics.linkCornerRadius)
          .strokeBorder(TLTheme.borderStroke, lineWidth: LicensePaneMetrics.strokeWidth)
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}

private enum LicensePaneCopy {
  static let productName = AppBrand.name
  static let proBadge = "PRO"
  static let proHint = "\(AppBrand.proName) unlocks cloud models, mode sync, and priority updates while keeping local dictation available."
  static let activeStatus = "Your Pro license is active"
  static let trialEndedStatus = "Your Pro trial has ended"
  static let licenseActiveButton = "License Active"
  static let activateButton = "Activate License"
  static let purchaseButton = "Purchase"
  static let discountLabel = "25% off"
  static let discountCode = "LOCAL25"
  static let roadmapLabel = "Roadmap"
  static let emailLabel = "Email"
  static let websiteLabel = "Website"
  static let discordLabel = "Discord"
  static let xLabel = "X"
  static let promoTitle = "Enjoying \(AppBrand.name)?"
  static let promoBody = "Use Pro to keep local dictation plus hosted models when you need extra speed or availability."
  static let seePlansButton = "See plans"
  static let dismissHelp = "Dismiss"
}

private enum LicensePaneIcons {
  static let roadmap = "point.topleft.down.curvedto.point.bottomright.up"
  static let email = "envelope.fill"
  static let website = "safari.fill"
  static let discord = "bubble.left.and.bubble.right.fill"
  static let x = "xmark"
  static let cloud = "cloud.fill"
  static let dismiss = "xmark"
}

private enum LicensePaneMetrics {
  static let stackSpacing: CGFloat = 0
  static let contentSpacing: CGFloat = 18
  static let contentSpacerMinLength: CGFloat = 20
  static let contentInsets = EdgeInsets(top: 18, leading: 24, bottom: 24, trailing: 24)
  static let brandSpacing: CGFloat = 8
  static let productFontSize: CGFloat = 14
  static let badgeFontSize: CGFloat = 10
  static let badgeHorizontalPadding: CGFloat = 6
  static let badgeVerticalPadding: CGFloat = 2
  static let badgeCornerRadius: CGFloat = 4
  static let statusFontSize: CGFloat = 12
  static let statusTopPadding: CGFloat = 3
  static let progressHeight: CGFloat = 8
  static let progressTopPadding: CGFloat = 18
  static let actionSpacing: CGFloat = 8
  static let buttonFontSize: CGFloat = 12
  static let buttonHorizontalPadding: CGFloat = 12
  static let buttonHeight: CGFloat = 30
  static let buttonCornerRadius: CGFloat = 7
  static let activeButtonOpacity = 0.10
  static let activeButtonStrokeOpacity = 0.06
  static let buttonStrokeOpacity = 0.18
  static let strokeWidth: CGFloat = 1
  static let discountFontSize: CGFloat = 11
  static let codeFontSize: CGFloat = 12
  static let codeHorizontalPadding: CGFloat = 12
  static let codeHeight: CGFloat = 26
  static let codeBackgroundOpacity = 0.14
  static let actionPadding: CGFloat = 8
  static let actionBackgroundOpacity = 0.045
  static let actionCornerRadius: CGFloat = 9
  static let actionTopPadding: CGFloat = 20
  static let cardPadding: CGFloat = 16
  static let cardCornerRadius: CGFloat = 14
  static let linkSpacing: CGFloat = 8
  static let linkContentSpacing: CGFloat = 7
  static let linkIconCornerRadius: CGFloat = 4
  static let linkIconFontSize: CGFloat = 11
  static let linkIconSize: CGFloat = 16
  static let linkFontSize: CGFloat = 13
  static let linkHorizontalPadding: CGFloat = 12
  static let linkHeight: CGFloat = 32
  static let linkCornerRadius: CGFloat = 8
  static let promoSpacing: CGFloat = 14
  static let promoIconCornerRadius: CGFloat = 14
  static let promoIconBackgroundOpacity = 0.14
  static let promoIconFontSize: CGFloat = 27
  static let promoIconSize: CGFloat = 56
  static let promoTextSpacing: CGFloat = 4
  static let promoTitleFontSize: CGFloat = 13
  static let promoBodyFontSize: CGFloat = 14
  static let seePlansFontSize: CGFloat = 13
  static let dismissTileSize: CGFloat = 22
  static let dismissHitSize: CGFloat = 28
  static let previewWidth: CGFloat = 620
  static let previewHeight: CGFloat = 700
}

#Preview("License") {
  @Previewable @State var store = AppPreviewState.makeStore()
  TLFloatingHost {
    LicensePane()
      .frame(width: LicensePaneMetrics.previewWidth, height: LicensePaneMetrics.previewHeight)
      .background(TLTheme.windowBackground)
  }
  .preferredColorScheme(store.settings.timberVoxSettings.appearancePreference.colorScheme)
}
