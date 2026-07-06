import SwiftUI

enum ActiveTab: String, CaseIterable, Identifiable {
  case home, modes, dictionary, history
  case configuration, hotMic, sound, models, license

  var id: String { rawValue }

  var label: String {
    switch self {
    case .home: "Home"
    case .modes: "Modes"
    case .dictionary: "Dictionary"
    case .history: "History"
    case .configuration: "Configuration"
    case .hotMic: "Hot Mic"
    case .sound: "Sound"
    case .models: "Model library"
    case .license: "License"
    }
  }

  var icon: String {
    switch self {
    case .home: "house"
    case .modes: "mic.fill"
    case .dictionary: "character.book.closed"
    case .history: "fossil.shell.fill"
    case .configuration: "slider.horizontal.3"
    case .hotMic: "waveform.circle"
    case .sound: "speaker.wave.2.fill"
    case .models: "square.stack.3d.up"
    case .license: "key.fill"
    }
  }

  var iconColor: Color {
    switch self {
    case .home: Color(hex: Shadcn.orange500)
    case .modes: Color(hex: Shadcn.blue500)
    case .dictionary: Color(hex: Shadcn.blue600)
    case .history: Color(hex: Shadcn.violet500)
    case .configuration: Color(hex: Shadcn.neutral500)
    case .hotMic: Color(hex: Shadcn.green500)
    case .sound: Color(hex: Shadcn.neutral500)
    case .models: Color(hex: Shadcn.neutral600)
    case .license: TLTheme.accentGreen
    }
  }

  static let libraryTop: [ActiveTab] = [.modes, .dictionary]
  static let settings: [ActiveTab] = [.configuration, .sound, .hotMic, .models]

  var debugName: String { rawValue }
}
