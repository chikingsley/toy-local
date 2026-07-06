import SwiftUI

enum TLProvider: Equatable {
  case fluidAudio
  case nvidia
  case openAI
  case deepgram
  case elevenLabs
  case cohere
  case anthropic
  case mistral
  case superwhisper

  var displayName: String {
    switch self {
    case .fluidAudio: "FluidAudio"
    case .nvidia: "NVIDIA"
    case .openAI: "OpenAI"
    case .deepgram: "Deepgram"
    case .elevenLabs: "ElevenLabs"
    case .cohere: "Cohere"
    case .anthropic: "Anthropic"
    case .mistral: "Mistral"
    case .superwhisper: "Superwhisper"
    }
  }

  var tileColor: Color {
    switch self {
    case .fluidAudio, .nvidia: Color(red: 0.45, green: 0.75, blue: 0.06)
    case .openAI: Color(red: 0.06, green: 0.55, blue: 0.42)
    case .deepgram: Color(red: 0.05, green: 0.70, blue: 0.44)
    case .elevenLabs: Color(red: 0.24, green: 0.22, blue: 0.92)
    case .cohere: Color(red: 0.90, green: 0.72, blue: 0.22)
    case .anthropic: Color(red: 0.90, green: 0.52, blue: 0.23)
    case .mistral: Color(red: 0.10, green: 0.10, blue: 0.10)
    case .superwhisper: Color(white: 0.45)
    }
  }

  var markColor: Color {
    switch self {
    case .fluidAudio, .nvidia, .cohere: .black.opacity(0.85)
    default: .white
    }
  }

  var logoAssetName: String? {
    switch self {
    case .fluidAudio, .nvidia: "provider-nvidia"
    case .openAI: "provider-openai"
    case .deepgram: "provider-deepgram"
    case .elevenLabs: "provider-elevenlabs"
    case .cohere: "provider-cohere"
    case .anthropic: "provider-anthropic"
    case .mistral: nil
    case .superwhisper: "provider-superwhisper"
    }
  }

  var logoPadding: CGFloat {
    switch self {
    case .fluidAudio, .nvidia: 4
    case .cohere: 2
    default: 5
    }
  }

}

struct TLProviderLogo: View {
  let provider: TLProvider
  var size: CGFloat = 24

  private var scale: CGFloat { size / 24 }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 6 * scale)
        .fill(provider.tileColor)

      if provider == .mistral {
        MistralProviderMark(scale: scale)
      } else if let assetName = provider.logoAssetName {
        Image(assetName)
          .resizable()
          .scaledToFit()
          .foregroundStyle(provider.markColor)
          .padding(provider.logoPadding * scale)
      } else {
        Text(String(provider.displayName.prefix(1)).uppercased())
          .font(.system(size: 10 * scale, weight: .bold))
          .foregroundStyle(provider.markColor)
      }
    }
    .frame(width: size, height: size)
  }
}

private struct MistralProviderMark: View {
  var scale: CGFloat = 1

  private let colors: [Color] = [
    Color(red: 1.00, green: 0.78, blue: 0.18),
    Color(red: 1.00, green: 0.56, blue: 0.08),
    Color(red: 0.93, green: 0.22, blue: 0.12),
  ]

  var body: some View {
    HStack(alignment: .bottom, spacing: 1.5 * scale) {
      ForEach(0..<5, id: \.self) { index in
        Rectangle()
          .fill(colors[index % colors.count])
          .frame(width: 2.5 * scale, height: (index == 2 ? 13 : 9) * scale)
      }
    }
  }
}
