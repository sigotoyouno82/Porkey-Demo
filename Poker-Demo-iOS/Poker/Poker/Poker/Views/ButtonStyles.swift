// ButtonStyles.swift
import SwiftUI

struct HighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(configuration.isPressed ? Color.blue.opacity(0.7) : Color.blue)
            )
            .foregroundColor(.white)
            .font(.headline)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
    }
}

struct HandButtonStyle: ViewModifier {
    var isShowdown: Bool
    func body(content: Content) -> some View {
        if isShowdown {
            content.buttonStyle(.borderedProminent)     // ショウダウン後は純正で目立たせる
        } else {
            content.buttonStyle(HighlightButtonStyle())  // 通常時は自作スタイル
        }
    }
}
