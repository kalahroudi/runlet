import SwiftUI

struct RLButtonStyle: ButtonStyle {
    var primary = false
    var small = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RLFont.body(small ? 12.5 : 14, .semibold))
            .padding(.horizontal, small ? 10 : 12)
            .padding(.vertical, small ? 5 : 7)
            .foregroundStyle(primary ? Color.white : Color.rlInk)
            .background(primary ? Color.rlAccent : Color.rlSurface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(primary ? Color.rlAccent : Color.rlLine))
            .brightness(configuration.isPressed ? -0.06 : 0)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 9))
            .modifier(HoverBrighten(primary: primary))
    }
}

private struct HoverBrighten: ViewModifier {
    let primary: Bool
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .brightness(hovering ? (primary ? 0.06 : -0.02) : 0)
            .onHover { hovering = $0 }
    }
}

extension ButtonStyle where Self == RLButtonStyle {
    static var rl: RLButtonStyle { RLButtonStyle() }
    static var rlPrimary: RLButtonStyle { RLButtonStyle(primary: true) }
    static var rlSmall: RLButtonStyle { RLButtonStyle(small: true) }
    static var rlSmallPrimary: RLButtonStyle { RLButtonStyle(primary: true, small: true) }
}

struct RLCard<Content: View>: View {
    var padding: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(Color.rlSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rlLine))
    }
}

struct RLChip: View {
    let text: String
    var selected = false

    var body: some View {
        Text(text)
            .font(RLFont.body(12, .semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .foregroundStyle(selected ? Color.rlBackground : Color.rlInk)
            .background(selected ? Color.rlInk : Color.rlSurface, in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.rlInk : Color.rlLine))
    }
}

struct RLSectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(RLFont.body(11, .semibold))
            .tracking(0.9)
            .foregroundStyle(Color.rlMuted)
    }
}

struct RLBanner<Trailing: View>: View {
    let icon: String
    let text: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color.rlAccent)
            Text(text).font(RLFont.body(13, .medium)).foregroundStyle(Color.rlInk).lineLimit(3).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(Color.rlAccentSoft, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Monospaced, green for success, red for errors.
struct RLStatusLine: View {
    let text: String
    var isError = false
    var isOK = false

    var body: some View {
        Text(text)
            .font(RLFont.mono(12))
            .foregroundStyle(isError ? Color.red : isOK ? Color.rlOK : Color.rlMuted)
    }
}
