import Foundation

struct Player: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var chips: Int
    var holeCards: [Card] = []

    // 🆕 ベッティング関連のプロパティ
    var currentBet: Int = 0       // 現在のベット額（このベットラウンド中）
    var hasFolded: Bool = false   // フォールドしているか
    var isAllIn: Bool = false     // オールイン状態か

    // 🆕 リセット用：次のラウンドに備えて
    mutating func resetForNewHand() {
        holeCards = []
        currentBet = 0
        hasFolded = false
        isAllIn = false
    }
}

/// プレイヤーが取りうるアクション
enum PlayerAction {
    /// 降りる（そのハンドは諦める）
    case fold
    /// そのまま（ベットなしで続行）
    case check
    /// 現在のベットに合わせる
    case call
    /// ベット額を上げる（指定したチップを追加）
    case raise(amount: Int)
    /// 持っているチップをすべて賭ける
    case allIn
}
