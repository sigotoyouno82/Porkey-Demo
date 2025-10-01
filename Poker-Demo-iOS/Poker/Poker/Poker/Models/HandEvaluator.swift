import Foundation

// MARK: - 役カテゴリ（強い → 弱い）
enum HandCategory: Int, Comparable, Codable, CaseIterable {
    case royalFlush = 10, straightFlush = 9, fourOfAKind = 8, fullHouse = 7, flush = 6
    case straight = 5, threeOfAKind = 4, twoPair = 3, onePair = 2, highCard = 1

    static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue }
}

// MARK: - 役の評価スコア
struct HandScore: Comparable, Codable {
    let category: HandCategory
    let ranks: [Int]
    let cards: [Card] // 実際の構成カード

    static func < (l: Self, r: Self) -> Bool {
        if l.category != r.category { return l.category < r.category }
        return l.ranks.lexicographicallyPrecedes(r.ranks)
    }
}

// MARK: - メイン判定ロジック
func evaluateBest5(from seven: [Card]) -> HandScore {
    precondition((5...7).contains(seven.count), "Hole2 + Board の合計 5〜7 枚を渡してください")

    var countByRank: [Int: Int] = [:]
    for c in seven { countByRank[c.rank.rawValue, default: 0] += 1 }

    let groups = countByRank.map { (rank: $0.key, cnt: $0.value) }
        .sorted { $0.cnt != $1.cnt ? $0.cnt > $1.cnt : $0.rank > $1.rank }

    // ストレートフラッシュ（ロイヤルフラッシュも判定）
    let flushInfo = isFlush(seven)
    if flushInfo.ok {
        let suited = seven.filter { $0.suit == flushInfo.suit }
        let suitedRanks = uniqueRanksDesc(from: suited)
        let st = isStraight(ranksDesc: suitedRanks)
        if st.ok {
            let best5 = suited.filter { card in
                // ストレートの top を基準に 5枚を選ぶ
                let cardValue = (card.rank.rawValue == 14 && st.top == 5) ? 1 : card.rank.rawValue
                return ((st.top - 4)...st.top).contains(cardValue)
            }
            
            // 型明示でステップを分ける
            let ranksOfBest5: [Rank] = best5.map { $0.rank }
            let sortedRanks: [Rank] = ranksOfBest5.sorted { a, b in a.rawValue > b.rawValue }
            let top5RanksInt: [Int] = sortedRanks.map { $0.rawValue }
            let royalSequence = [14, 13, 12, 11, 10]
            let isRoyal = top5RanksInt == royalSequence
            
            return HandScore(
                category: isRoyal ? .royalFlush : .straightFlush,
                ranks: [st.top],
                cards: Array(best5.prefix(5))
            )
        }
    }

    // フォーカード
    if let quad = groups.first, quad.cnt == 4 {
        let kicker = seven.filter { $0.rank.rawValue != quad.rank }
            .sorted { $0.rank.rawValue > $1.rank.rawValue }
            .prefix(1)
        let quadCards = seven.filter { $0.rank.rawValue == quad.rank }.prefix(4)
        return HandScore(category: .fourOfAKind, ranks: [quad.rank, kicker.first?.rank.rawValue ?? 0], cards: Array(quadCards + kicker))
    }

    // フルハウス
    let trips = groups.filter { $0.cnt == 3 }
    let pairsOrTrips = groups.filter { $0.cnt >= 2 }
    if let t = trips.first, let p = pairsOrTrips.first(where: { $0.rank != t.rank }) {
        let tripCards = seven.filter { $0.rank.rawValue == t.rank }.prefix(3)
        let pairCards = seven.filter { $0.rank.rawValue == p.rank }.prefix(2)
        return HandScore(category: .fullHouse, ranks: [t.rank, p.rank], cards: Array(tripCards + pairCards))
    }

    // フラッシュ
    if flushInfo.ok {
        let suited = seven.filter { $0.suit == flushInfo.suit }
            .sorted { $0.rank.rawValue > $1.rank.rawValue }
            .prefix(5)
        return HandScore(category: .flush, ranks: suited.map { $0.rank.rawValue }, cards: Array(suited))
    }

    // ストレート
    let allRanks = uniqueRanksDesc(from: seven)
    let st = isStraight(ranksDesc: allRanks)
    if st.ok {
        let best5 = seven.filter {
            let v = $0.rank.rawValue == 14 && st.top == 5 ? 1 : $0.rank.rawValue
            return (st.top - 4)...st.top ~= v
        }
        return HandScore(category: .straight, ranks: [st.top], cards: Array(best5.prefix(5)))
    }

    // スリーカード
    if let t = trips.first {
        let tripCards = seven.filter { $0.rank.rawValue == t.rank }.prefix(3)
        let kickers = seven.filter { $0.rank.rawValue != t.rank }
            .sorted { $0.rank.rawValue > $1.rank.rawValue }
            .prefix(2)
        return HandScore(category: .threeOfAKind, ranks: [t.rank] + kickers.map { $0.rank.rawValue }, cards: Array(tripCards + kickers))
    }

    // ツーペア
    let onlyPairs = groups.filter { $0.cnt == 2 }
    if onlyPairs.count >= 2 {
        let top2 = Array(onlyPairs.prefix(2)).map { $0.rank }
        let pair1 = seven.filter { $0.rank.rawValue == top2[0] }.prefix(2)
        let pair2 = seven.filter { $0.rank.rawValue == top2[1] }.prefix(2)
        let kicker = seven.filter { !top2.contains($0.rank.rawValue) }
            .sorted { $0.rank.rawValue > $1.rank.rawValue }
            .prefix(1)
        return HandScore(category: .twoPair, ranks: top2 + [kicker.first?.rank.rawValue ?? 0], cards: Array(pair1 + pair2 + kicker))
    }

    // ワンペア
    if let p = onlyPairs.first {
        let pairCards = seven.filter { $0.rank.rawValue == p.rank }.prefix(2)
        let kickers = seven.filter { $0.rank.rawValue != p.rank }
            .sorted { $0.rank.rawValue > $1.rank.rawValue }
            .prefix(3)
        return HandScore(category: .onePair, ranks: [p.rank] + kickers.map { $0.rank.rawValue }, cards: Array(pairCards + kickers))
    }

    // ハイカード
    let best5 = seven.sorted { $0.rank.rawValue > $1.rank.rawValue }.prefix(5)
    return HandScore(category: .highCard, ranks: best5.map { $0.rank.rawValue }, cards: Array(best5))
}

// MARK: - ヘルパー群

@inline(__always)
func uniqueRanksDesc(from cards: [Card]) -> [Int] {
    var seen = Set<Int>(), out: [Int] = []
    for r in cards.map({ $0.rank.rawValue }).sorted(by: >) {
        if seen.insert(r).inserted { out.append(r) }
    }
    return out
}

@inline(__always)
func isStraight(ranksDesc: [Int]) -> (ok: Bool, top: Int) {
    guard !ranksDesc.isEmpty else { return (false, 0) }
    var arr = ranksDesc
    if arr.first == 14 { arr.append(1) }
    var run = 1, bestTop = 0
    for i in 1..<arr.count {
        if arr[i] == arr[i-1] - 1 {
            run += 1
            if run >= 5 { bestTop = max(bestTop, arr[i-4]) }
        } else if arr[i] != arr[i-1] {
            run = 1
        }
    }
    return (bestTop > 0, bestTop)
}

@inline(__always)
func isFlush(_ cards: [Card]) -> (ok: Bool, suit: Suit, ranksDesc: [Int]) {
    var suitMap: [Suit: [Card]] = [:]
    for c in cards { suitMap[c.suit, default: []].append(c) }
    if let (suit, suited) = suitMap.first(where: { $0.value.count >= 5 }) {
        let top5 = suited.map { $0.rank.rawValue }.sorted(by: >).prefix(5)
        return (true, suit, Array(top5))
    }
    return (false, .spades, [])
}

// MARK: - 2人勝負の勝者判定
enum HeadsUpResult {
    case leftWins, rightWins, split
}

func compareHeadsUp(holeA: [Card], holeB: [Card], board: [Card]) -> HeadsUpResult {
    let scoreA = evaluateBest5(from: holeA + board)
    let scoreB = evaluateBest5(from: holeB + board)
    
    if scoreA.category != scoreB.category {
        return scoreA.category > scoreB.category ? .leftWins : .rightWins
    }
    
    if scoreA.ranks != scoreB.ranks {
        return scoreA.ranks.lexicographicallyPrecedes(scoreB.ranks) ? .rightWins : .leftWins
    }

    // 最後に、カードの組み合わせ自体が全く同じかどうかで Split
    if Set(scoreA.cards) == Set(scoreB.cards) {
        return .split
    }

    // カテゴリ・ランク一致でもカードが違えば判定（ルール次第）
    return .split
}
