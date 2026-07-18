import AppKit
import SwiftUI

enum ModeLayout {
  static let controlWidth: CGFloat = 200
  static let modelPopoverWidth: CGFloat = 336
  static let controlHeight: CGFloat = 32
}

struct ModeProviderTile: View {
  let provider: String
  let runtime: TranscriptionModelRuntime?
  var size: CGFloat = 28

  @Environment(\.theme) private var theme

  var body: some View {
    Group {
      if provider.lowercased() == "gemini" {
        GeminiProviderMark()
          .frame(width: size * 0.58, height: size * 0.58)
      } else if let providerImage = ModeProviderLogo.image(for: provider) {
        Image(nsImage: providerImage)
          .interpolation(.none)
          .resizable()
          .scaledToFit()
          .frame(width: size * 0.58, height: size * 0.58)
      } else if runtime == .local {
        Image(systemName: runtime == .local ? "cpu" : "waveform")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(providerForeground)
      } else {
        Text(provider.prefix(1).uppercased())
          .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
          .foregroundStyle(providerForeground)
      }
    }
    .frame(width: size, height: size)
    .background(providerBackground, in: shape)
    .overlay {
      shape.strokeBorder(theme.border.opacity(0.6))
    }
    .help(provider)
    .accessibilityLabel(provider)
  }

  private var providerBackground: Color {
    switch provider.lowercased() {
    case "anthropic": Color(red: 0.77, green: 0.56, blue: 0.44)
    case "deepgram": Color(red: 0.62, green: 0.20, blue: 0.24)
    case "gemini": Color(white: 0.95)
    case "grok": Color(white: 0.12)
    case "meta": Color(red: 0.02, green: 0.40, blue: 0.87)
    case "mistral": Color(red: 0.98, green: 0.32, blue: 0.06)
    case "nvidia": Color(red: 0.46, green: 0.73, blue: 0)
    case "openai": Color(red: 0.06, green: 0.64, blue: 0.50)
    case "elevenlabs", "superwhisper": .white
    default: theme.muted
    }
  }

  private var providerForeground: Color {
    switch provider.lowercased() {
    case "nvidia", "mistral", "deepgram", "anthropic", "gemini", "openai", "elevenlabs",
      "superwhisper":
      .black.opacity(0.82)
    default: theme.mutedForeground
    }
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: max(size * 0.27, 4), style: .continuous)
  }
}

private struct GeminiProviderMark: View {
  var body: some View {
    GeminiProviderShape()
      .fill(
        LinearGradient(
          colors: [Color(red: 0.20, green: 0.48, blue: 0.96), Color(red: 0.70, green: 0.34, blue: 0.88)],
          startPoint: .bottomLeading,
          endPoint: .topTrailing
        )
      )
  }
}

private struct GeminiProviderShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.midY))
    path.addQuadCurve(
      to: CGPoint(x: rect.midX, y: rect.minY),
      control: CGPoint(x: rect.midX * 0.72, y: rect.midY * 0.72)
    )
    path.addQuadCurve(
      to: CGPoint(x: rect.maxX, y: rect.midY),
      control: CGPoint(x: rect.midX * 1.28, y: rect.midY * 0.72)
    )
    path.addQuadCurve(
      to: CGPoint(x: rect.midX, y: rect.maxY),
      control: CGPoint(x: rect.midX * 1.28, y: rect.midY * 1.28)
    )
    path.addQuadCurve(
      to: CGPoint(x: rect.minX, y: rect.midY),
      control: CGPoint(x: rect.midX * 0.72, y: rect.midY * 1.28)
    )
    return path
  }
}

enum ModeProviderLogo {
  private static let images: [String: NSImage] = [
    "anthropic": image(
      "iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAADqADAAQAAAABAAAADgAAAACeOBvAAAABOklEQVQoFdVQu0rEQBS9dxJ/wE7EJBgEIWVs1ULEJ2xrp+iutf8gaGFnK2Jjb7WyIKy1YOEPCJuH2MReJDPXM2GzDGIteOFy5sx9H6K/Nv4x0A/D8EREFOyyrusF4Bb4sCiKZzfXd0kURbti9IXtZox5BwyZ5IyZHvFed3OVS9D5GFzDvxRJryzLNzS5B18LgmDezZ0UxnE8R2I2iGQgxHdCtIwNFg3xFQrsEt1fC7XWRwgoYu8aaJ2wQTfPczsRk+UAODmtnahw0yECNXwagswCP7HBfpIkHrG6AZ+xGgAba1SFkttI6refLrLy9sCfINorGgyyLNux8WbiWBQyQh3ctzR2q6IRU/dGMPw9oPlmowUCnKbpVFVVHyzmZZQXK7Zba9ikj+RV5fkJTknxvsUGp+hz3ub8A/wGTheAUyUntH8AAAAASUVORK5CYII="
    ),
    "deepgram": image(
      "iVBORw0KGgoAAAANSUhEUgAAAAsAAAALCAYAAACprHcmAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAC6ADAAQAAAABAAAACwAAAACidng8AAAAzklEQVQYGXWPMQoCMRBFE5XtBAVhS0HwDBbWFluKd7DzDB5CEBsbD7GFhY1WWojHEAWxFDHxZZZIsrgDf37+zJ9Joq21PaVUE4TxQly11o+wqIwxOwaqIqeR+oGaP1RwhnkPWq5fNufUVmDrmi54Sh+aiyg9I5MiiW1TIIHn5uoNJs9w3QniXpDkNXkBEjwdppKgFx9pdmVtkQwUP5lCG6RgyNUn2MchWkV1At6+G7DbOvqZEWPwz/ihPvNGjRggNrB8gM9Y9BMcwRJ9gSW+pv7Jc5OznNMAAAAASUVORK5CYII="
    ),
    "mistral": image(
      "iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAADqADAAQAAAABAAAADgAAAACeOBvAAAAAZElEQVQoFWNgGDDwHwpwOQBdngmXQkLiLOgKQCaDxBiBAETD+CA2MqCejTBTcdkEkyfbRgyNIL+BAMxkCA/Bh4ljaIRJEKIZcfjlN9AmNpBmoPwvIMWKbhAuG5GjCZmNrp+OfAAIyiUSstZj8gAAAABJRU5ErkJggg=="
    ),
    "nvidia": image(
      "iVBORw0KGgoAAAANSUhEUgAAAA8AAAALCAYAAACgR9dcAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAD6ADAAQAAAABAAAACwAAAADRfl/zAAABkklEQVQoFW1SMUgDUQxN/v1aRLAtqCAK10JBHRWKo9SlIoqCoIM6CKJF0EGcxcnBycXNxclJEN3FycFFHJRSRegm0uVKtXD1fnx3tcXKfcglP3lJXn6OKeSk0+mo67rpkFDgYmZTKpVeOAxg2/YIiXkOi7V8rE506wIjmUxOiMgqxFLKmkeHmjFmCoU2EO76i4U9YPmOVCplx2Kxc5gJgI+RVIU9I8ZbY6UeRSjPrMaJZNDHB4e5oEBx1HjfD0g4Q8eiUuoU4oPuenr7xsh4w0zmwPO8SSQXflMD5dN+h0TR8RMFlmBfwL5hkqdyuTxErLIotkJslkE/iXgN0gkhy3GcajyeqCiSfSOSR9IR5nVIJEtkLGXpTfHqc8BuodCspfWhGJMh5q9gZhS4747F+9FhG851MLAx4zUR1zDKnhAXtY4saq2der2+gxUtAPfatiq8dg6UdzFjRUhdodgH7mXoDIrkQHsaDDp8ymBx2ZYcOPFp7Nm7BSKOawPcDDb1/z03/ZFI5M11Ba8bfjBW8If9AFdtmjZimqK/AAAAAElFTkSuQmCC"
    ),
    "grok": image(
      "iVBORw0KGgoAAAANSUhEUgAAAA4AAAANCAYAAACZ3F9/AAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAADqADAAQAAAABAAAADQAAAADZmGEQAAABOUlEQVQoFZWSP0uCURSHvWbQEBpIoi+2Cq5ikxItze5tfgHpG4Tg7CeIwMXZpTYdSwRBmqqhhtCWltBF0/f6nJd79fpn6cLD75zzO+fe+15eFfrn0lonGJmq7TkMqV1ADhbQU0p10RCeh1yRNyRfLYwsDED7vj8RCOdwAx55H42uBiSgcIoxQl+gaGph4jh48Ibf3hgyTQ2MTxpirkmeglfA9juuJ6cdUByjFdcgT8IjnEOdni/Xl8EEyLq0BrEMVSG4AVoG+d7gQSOm8Redg7yabCQPkOH1biU3K43+UNO2ECjXaEOXoQgcuib5MXzAna2HbcBO73BEHkP/bJ3mJHELTqBm64GaHe/RKFRgyOlP6DPMiL/RgjukKMipJXjgpBm57HwNeZDv6UETb4yuF41nsPPrrTv2R0tFyf+r7NVDTAAAAABJRU5ErkJggg=="
    ),
    "meta": image(
      "iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAADqADAAQAAAABAAAADgAAAACeOBvAAAABI0lEQVQoFcWQP0tCYRTGr+RgIejWHNUehCC4CyJEEE3VZ8ilpVFyCgIH/QLuDUEELurm0FBDQURRiwRG5h/CyPvefs+lN17uB6gDP85znnPO+773et6/RBAEcWiBD+++71fJCT2GvG+M6ZNf4BBiv4+kuATFEzRABzShDA9QhF14g0q4iFgDA6f2JPQeKD5hxfE3qb9Cj2fVecqEIukMLOCN8HRg1vrK1HdwJHELZ5HmCd49yz3yFczZProGHS1+wLHTyFDPYAN2QFFy+gfUj1rkYNNVAz2PviE3ncE23hhv6WfmHD31MF8RA9iCC2p927KzuIqnf3ANJZjCs27JgRZ19ZCUt0s24xXp6VaFfth22EMkYR1Sdjia6aWhAIvR3t/U3+I/Y/v1m6ISAAAAAElFTkSuQmCC"
    ),
    "openai": image(
      "iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAD6ADAAQAAAABAAAADwAAAAAk/vkzAAABsElEQVQoFW3TTyiDYRzA8fd90ZZoE8VKapJWMuKiIaVd5DLkIg7WDg5u7OKgnKwkDhyUHEhZCS2lFK2UKUX+zJ+Sljg6uChlm+9v3mfJ9tRnv9/7PM/veZ/nfd9pWp6WTqcNlMKaZzjbpWczM6FghHQCl3DiC6uwIabrepyY2ytsxAGKocOfSqWeiCEEEcNCTiWdlUw8JrrRQn5KXIQdNWaU4+xiMLsAF+1MjhNfYUsmk2GiFyWYxS3uEIAHW1JsmCsscZYeOp8znYYhz8IDObcfA5AbNBJXmFdE1ApJLMQExS8MSp9q1SRtkIJtRAzDmCLWMneDOoe6sywg7RtdmUzT5pn0jiiLntBXhTMkMY1hg0F5FeWs5CYPkMs2e1EG1ewkawhDdhJjQae68xgdUXjRjz4WW0aISUdst5s+aepcDfS9qeIPBq7gQgxWdnFN7CAGWWCHXDV5bXNcyC40jQsLHiAfhwubGDLHfOSPqMMMbqB2kqmXBSYRgTwYuW7CIdbhQAHkC6v4rfj3y8AoWzzHPXkCe6hHs5mP/y3J+WOoQSbLh+BDKz6xz/kviNn2AwOZRIT3oQFiAAAAAElFTkSuQmCC"
    ),
    "superwhisper": image(
      "iVBORw0KGgoAAAANSUhEUgAAAA0AAAAMCAYAAAC5tzfZAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAADaADAAQAAAABAAAADAAAAAC3YhMkAAAA5UlEQVQoFX2POwrCQBRFM1EhpZVFegsbMZWg69AuhSvIAhQsbN2DuhXBDbgCRQsljYUiiMl4XpiE/PDBycv9TD6WVTNa6yEsZdfEVYuiBx+Qke1VWyUnjuN9UjcX0aVKUdKbmO6NHXAgNHpabBpF6MAJHtATmz2AF4jvVA5izkFmlg/RQeJqvcj78kSXT3myz2DnQ3QLriZ3swxzBzKrzMzd4K+TlJ7YNqLL9k3nbna2yOXNoTF86SsuI4xD2kJflFJH9Bs60Ic2pDOW/5GDG4jg30i+BaXS44gG981U1+wvXxCJ/wMYxPkzhCDYPAAAAABJRU5ErkJggg=="
    ),
    "elevenlabs": image(
      "iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAAXNSR0IArs4c6QAAADhlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAADqADAAQAAAABAAAADgAAAACeOBvAAAAASUlEQVQoFY2RwQkAMAgD7f6LdR0XddAVHHxVemhFAgQSHkDFk/NKfkJUJOAHusFqlz1KXUzTUTBFSa6Ik1wRJ7kiTrJL38vXY/8AW7IHDhBjzRMAAAAASUVORK5CYII="
    ),
  ]

  static func image(for provider: String) -> NSImage? {
    images[provider.lowercased()]
  }

  private static func image(_ base64: String) -> NSImage {
    guard let data = Data(base64Encoded: base64), let image = NSImage(data: data) else {
      assertionFailure("Embedded provider logo is invalid")
      return NSImage()
    }
    return image
  }
}
