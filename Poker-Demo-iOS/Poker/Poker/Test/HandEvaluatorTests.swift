import Testing
@testable import Test   // ← あなたのアプリの Product Name に合わせて

struct HandEvaluatorTests {

    // 骨組み段階でも通る“生存確認”テスト
    @Test
    func evaluate_returnsSomethingComparable() {
        let seven: [Card] = [
            .init(rank: .ace,   suit: .spades),
            .init(rank: .king,  suit: .hearts),
            .init(rank: .queen, suit: .clubs),
            .init(rank: .jack,  suit: .diamonds),
            .init(rank: .ten,   suit: .spades),
            .init(rank: .two,   suit: .clubs),
            .init(rank: .three, suit: .hearts),
        ]
        let s = evaluateBest5(from: seven)
        #expect(s.ranks.first != nil)
        #expect(s.category >= .highCard)
    }

    // カウント系が動いているか（ツーペアの順序とキッカー）
    @Test
    func evaluate_detectsTwoPairInRankOrder() {
        // A A / K K / Q / 2 / 3 → ツーペア（AとK）、キッカーQ
        let seven: [Card] = [
            .init(rank: .ace,   suit: .spades),
            .init(rank: .ace,   suit: .hearts),
            .init(rank: .king,  suit: .clubs),
            .init(rank: .king,  suit: .diamonds),
            .init(rank: .queen, suit: .spades),
            .init(rank: .two,   suit: .clubs),
            .init(rank: .three, suit: .hearts),
        ]
        let s = evaluateBest5(from: seven)
        #expect(s.category == .twoPair)
        // ranks は [高いペア, 次のペア, キッカー] の想定
        #expect(s.ranks.count >= 3)
        #expect(s.ranks[0] == Rank.ace.rawValue)
        #expect(s.ranks[1] == Rank.king.rawValue)
        #expect(s.ranks[2] == Rank.queen.rawValue)
    }
}
