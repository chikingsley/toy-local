import SwiftUI
import ToyLocalCore

struct GeneralPane: View {
  @Bindable var store: SettingsStore
  let microphonePermission: PermissionStatus
  let accessibilityPermission: PermissionStatus
  let screenCapturePermission: PermissionStatus
  let requestMicrophonePermission: () -> Void
  let requestAccessibilityPermission: () -> Void
  let requestScreenCapturePermission: () -> Void

  var body: some View {
    Form {
      PermissionsSectionView(
        microphonePermission: microphonePermission,
        accessibilityPermission: accessibilityPermission,
        screenCapturePermission: screenCapturePermission,
        requestMicrophonePermission: requestMicrophonePermission,
        requestAccessibilityPermission: requestAccessibilityPermission,
        requestScreenCapturePermission: requestScreenCapturePermission
      )

      GeneralSectionView(store: store)
    }
    .formStyle(.grouped)
  }
}

#Preview {
  GeneralPane(
    store: AppPreviewState.makeStore().settings,
    microphonePermission: .granted,
    accessibilityPermission: .granted,
    screenCapturePermission: .granted,
    requestMicrophonePermission: {},
    requestAccessibilityPermission: {},
    requestScreenCapturePermission: {}
  )
  .frame(width: 660, height: 560)
}
