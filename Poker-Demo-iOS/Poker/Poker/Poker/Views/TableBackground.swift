//
//  TableBackground.swift
//  Test
//
//  Created by 粟野　隼斗 on 2025/09/09.
//

import SwiftUI

/// 画面全体のフェルト背景
struct FeltBackground: View {
    var body: some View {
        RadialGradient(
            colors: [Color(hex: 0x0A5E2A), Color(hex: 0x06471F)],
            center: .center, startRadius: 60, endRadius: 500
        )
        .ignoresSafeArea()
    }
}

/// 楕円形のテーブル面
struct TableSurface<Content: View>: View {
    var content: () -> Content
    var body: some View {
        ZStack {
            // テーブル面
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color(hex: 0x166B33), Color(hex: 0x0D5527)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
                .overlay(
                    // 縁
                    Ellipse().stroke(Color.white.opacity(0.12), lineWidth: 4)
                )
            content()
                .padding(.vertical, 24)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 700, maxHeight: 520)
    }
}

// 小さな便利拡張：16進で色指定
private extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: alpha
        )
    }
}
