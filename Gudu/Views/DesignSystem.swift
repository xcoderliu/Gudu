import SwiftUI

enum Palette {
    static let background = Color(hex: 0xF7F9F8)
    static let sidebar = Color(hex: 0xEDF2F0)
    static let ink = Color(hex: 0x183D37)
    static let secondary = Color(hex: 0x7A8C86)
    static let accent = Color(hex: 0x278871)
    static let mint = Color(hex: 0xB6E5CF)
    static let line = Color(hex: 0xE3EBE6)
    static let ocean = Color(hex: 0x103F3E)
}

private struct StaticAnimationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Deterministic stills for documentation rendering; system Reduce Motion
    /// remains a separate, read-only accessibility environment value.
    var guduStaticAnimation: Bool {
        get { self[StaticAnimationKey.self] }
        set { self[StaticAnimationKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

struct FilledButtonStyle: ButtonStyle {
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .foregroundStyle(prominent ? Color.white : Palette.ink)
            .background(prominent ? Palette.accent : Color.white,
                        in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11)
                .strokeBorder(prominent ? Color.clear : Palette.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 11))
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content

    var body: some View {
        content.frame(maxWidth: .infinity, alignment: .leading).padding(padding)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.line, lineWidth: 1))
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
            if let subtitle {
                Text(subtitle).font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }
        }
    }
}

func clockText(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
