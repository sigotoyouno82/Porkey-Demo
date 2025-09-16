import Foundation

struct Deck {
    private(set) var cards: [Card] = {
        var c: [Card] = []
        for s in Suit.allCases { for r in Rank.allCases { c.append(Card(rank: r, suit: s)) } }
        return c
    }()

    /// ハンド開始時に1回だけ呼ぶ
    mutating func shuffle() {
        cards.shuffle()
    }

    /// 1枚引く（無ければ nil）
    mutating func draw() -> Card? {
        guard !cards.isEmpty else { return nil }
        return cards.removeFirst()
    }

    /// n枚引く（不足分は捨てる）
    mutating func draw(_ n: Int) -> [Card] {
        (0..<n).compactMap { _ in draw() }
    }
}

