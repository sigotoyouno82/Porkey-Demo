import SwiftUI

struct MiniCardView: View {
    let card: Card
    var faceUp: Bool = true
    var highlighted: Bool = false // ← ★ 勝者カードかどうか
    var size = CGSize(width: 58, height: 78)

    @State private var flipped = false

    var body: some View {
        ZStack {
            cardBack
                .opacity(faceUp ? 0 : 1)
                .rotation3DEffect(.degrees(faceUp ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            cardFront
                .opacity(faceUp ? 1 : 0)
                .rotation3DEffect(.degrees(faceUp ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(width: size.width, height: size.height)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(highlighted ? Color.yellow.opacity(0.9) : Color.clear, lineWidth: 4)
                .shadow(color: highlighted ? Color.yellow.opacity(0.5) : Color.clear, radius: highlighted ? 6 : 0)
        )
        .animation(.easeInOut(duration: 0.4), value: highlighted)
        .onChange(of: faceUp) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                flipped.toggle()
            }
        }
    }

    private var cardFront: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.black.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)

            VStack(spacing: 2) {
                Text(card.rank.symbol).font(.title2).bold()
                Text(card.suit.symbol).font(.title3)
            }
            .foregroundStyle(card.suit.color)
        }
    }

    private var cardBack: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.15, green: 0.45, blue: 0.95),
                             Color(red: 0.02, green: 0.2,  blue: 0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
    }
}

extension Rank {
    var symbol: String {
        switch self {
        case .ace: return "A"
        case .king: return "K"
        case .queen: return "Q"
        case .jack: return "J"
        default: return String(self.rawValue)
        }
    }
}

extension Suit {
    var symbol: String {
        switch self {
        case .hearts: return "♥︎"
        case .diamonds: return "♦︎"
        case .clubs: return "♣︎"
        case .spades: return "♠︎"
        }
    }

    var color: Color {
        switch self {
        case .hearts, .diamonds: return .red
        case .clubs, .spades: return .black
        }
    }
}
