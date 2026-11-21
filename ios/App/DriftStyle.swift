import SwiftUI

enum DriftStyle {
    static let background = Color(red: 0.025, green: 0.047, blue: 0.047)
    static let panel = Color(red: 0.051, green: 0.083, blue: 0.083)
    static let raised = Color(red: 0.067, green: 0.110, blue: 0.108)
    static let border = Color(red: 0.155, green: 0.224, blue: 0.212)
    static let mint = Color(red: 0.59, green: 0.99, blue: 0.75)
    static let amber = Color(red: 1, green: 0.74, blue: 0.42)
    static let ink = Color(red: 0.92, green: 0.97, blue: 0.95)
    static let muted = Color(red: 0.61, green: 0.71, blue: 0.68)
}

struct DriftActionStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: 45)
            .padding(.horizontal, 13)
            .foregroundStyle(primary ? DriftStyle.background : DriftStyle.ink)
            .background(primary ? DriftStyle.mint : DriftStyle.raised, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if !primary {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(DriftStyle.border)
                }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct Panel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(15)
            .background(DriftStyle.panel, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(DriftStyle.border) }
    }
}

extension View {
    func driftPanel() -> some View { modifier(Panel()) }
}
