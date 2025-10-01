//  GameVM.swift
import Foundation
import SwiftUI
import Combine

@MainActor
final class GameVM: ObservableObject {

    // MARK: - 公開状態（Viewが監視）
    @Published var players: [Player] = []
    @Published var board: [Card] = []
    @Published var pot: Int = 0
    @Published var handEnded: Bool = false
    @Published var currentBet: Int = 0
    @Published var currentPlayerIndex: Int = 0
    @Published var revealCPUHole: Bool = false
    @Published var isShowdown: Bool = false
    @Published var street: Street = .preflop

    // MARK: - 演出用
    @Published var recentChipsMoved: Int = 0

    enum Street: Int {
        case preflop, flop, turn, river, showdown
    }

    private var acted: [Bool] = [false, false]
    private let smallBlind = 10
    private let bigBlind   = 20
    private var dealerIndex = 0

    private var fullBoard: [Card] = []
    private var revealedCount: Int = 0
    
    let cpuActionSubject = PassthroughSubject<String, Never>()

    init() {
        startNewPracticeHand()
    }

    var nextStreetTitle: String {
        switch board.count {
        case 0: return "フロップを公開"
        case 3: return "ターンを公開"
        case 4: return "リバーを公開"
        default: return ""
        }
    }

    var canRevealNext: Bool {
        board.count < 5
    }

    var callAmount: Int {
        guard players.indices.contains(currentPlayerIndex) else { return 0 }
        return max(0, currentBet - players[currentPlayerIndex].currentBet)
    }

    func startNewPracticeHand() {
        dealerIndex = (players.isEmpty ? 0 : (dealerIndex + 1) % 2)

        players = [
            Player(name: "You", chips: 1000),
            Player(name: "CPU", chips: 1000)
        ]

        for i in players.indices {
            players[i].currentBet = 0
            players[i].isAllIn = false
            players[i].hasFolded = false
        }

        acted = [false, false]
        currentBet = 0
        pot = 0
        board = []
        revealedCount = 0
        revealCPUHole = false
        isShowdown = false
        handEnded = false
        street = .preflop
        recentChipsMoved = 0

        var deck = Deck()
        deck.shuffle()
        players[0].holeCards = deck.draw(2)
        players[1].holeCards = deck.draw(2)
        fullBoard = deck.draw(5)

        let sb = dealerIndex
        let bb = 1 - dealerIndex
        forceBet(playerIndex: sb, amount: smallBlind)
        forceBet(playerIndex: bb, amount: bigBlind)

        startBettingRound(resetBets: false)
        maybeActCPUIfNeeded()
    }

    private func forceBet(playerIndex: Int, amount: Int) {
        guard players.indices.contains(playerIndex) else { return }
        var p = players[playerIndex]
        let bet = min(p.chips, amount)
        p.chips -= bet
        p.currentBet += bet
        pot += bet
        p.isAllIn = (p.chips == 0)
        currentBet = max(currentBet, p.currentBet)
        players[playerIndex] = p
        recentChipsMoved = bet
    }

    private func startBettingRound(resetBets: Bool) {
        acted = [false, false]
        if resetBets {
            currentBet = 0
            for i in players.indices { players[i].currentBet = 0 }
        }
        currentPlayerIndex = dealerIndex
    }

    func maybeActCPUIfNeeded() {
        guard currentPlayerIndex == 1, !isShowdown, !handEnded else { return }
        let delay: TimeInterval = 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            let cpu = self.players[1]
            let c = self.callAmount

            let action: PlayerAction
            if c == 0 {
                if cpu.chips > 0, Int.random(in: 0..<10) == 0 {
                    action = .raise(amount: min(60, cpu.chips))
                } else {
                    action = .check
                }
            } else if c <= min(60, cpu.chips) {
                action = .call
            } else {
                action = .fold
            }
            self.performAction(action)
        }
    }

    func performAction(_ action: PlayerAction) {
        guard players.indices.contains(currentPlayerIndex),
              street != .showdown, !handEnded else { return }

        acted[currentPlayerIndex] = true

        let isCPU = currentPlayerIndex == 1
        if isCPU {
            switch action {
            case .fold: cpuActionSubject.send("フォールド")
            case .check: cpuActionSubject.send("チェック")
            case .call: cpuActionSubject.send("コール")
            case .raise: cpuActionSubject.send("レイズ")
            case .allIn: cpuActionSubject.send("オールイン")
            }
        }

        // 💥 現在のプレイヤーの行動を処理（ここまで）

        switch action {
        case .fold:
            players[currentPlayerIndex].hasFolded = true
            if players.filter({ !$0.hasFolded }).count == 1 {
                goToShowdown()
                return
            }
        case .check:
            break
        case .call:
            let toCall = currentBet - players[currentPlayerIndex].currentBet
            playerBet(amount: toCall)
        case .raise(let amount):
            playerBet(amount: amount)
        case .allIn:
            let chips = players[currentPlayerIndex].chips
            playerBet(amount: chips)
            if isHandInAllInState() {
                revealCPUHole = true
                revealAllBoardAndShowdown()
                return
            }
        }

        // ✅ ラウンドが終了していれば次へ
        if isBettingRoundOver() {
            proceedToNextStreet()
        } else {
            nextPlayerTurn()
        }
    }

    func playerBet(amount: Int) {
        guard players.indices.contains(currentPlayerIndex) else { return }
        var player = players[currentPlayerIndex]
        let totalBet = min(player.chips, amount)
        player.chips -= totalBet
        player.currentBet += totalBet
        pot += totalBet
        player.isAllIn = (player.chips == 0)
        currentBet = max(currentBet, player.currentBet)
        players[currentPlayerIndex] = player
        recentChipsMoved = totalBet
    }

    func nextPlayerTurn() {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        if !isBettingRoundOver() { maybeActCPUIfNeeded() }
    }

    func isBettingRoundOver() -> Bool {
        let active = players.enumerated().filter { !$0.element.hasFolded && !$0.element.isAllIn }
        if active.count <= 1 { return true }

        func actedOrFrozen(_ idx: Int) -> Bool {
            players[idx].hasFolded || players[idx].isAllIn || acted[idx]
        }
        guard actedOrFrozen(0) && actedOrFrozen(1) else { return false }

        let bets = active.map { $0.element.currentBet }
        return Set(bets).count == 1
    }

    func proceedToNextStreet() {
        switch street {
        case .preflop: revealFlop()
        case .flop: revealTurn()
        case .turn: revealRiver()
        case .river: goToShowdown()
        case .showdown: break
        }
    }

    private func revealFlop() {
        board = Array(fullBoard.prefix(3))
        revealedCount = 3
        street = .flop
        startBettingRound(resetBets: true)
        maybeActCPUIfNeeded()
    }

    private func revealTurn() {
        board = Array(fullBoard.prefix(4))
        revealedCount = 4
        street = .turn
        startBettingRound(resetBets: true)
        maybeActCPUIfNeeded()
    }

    private func revealRiver() {
        board = fullBoard
        revealedCount = 5
        street = .river
        startBettingRound(resetBets: true)
        maybeActCPUIfNeeded()
    }

    func goToShowdown() {
        guard board.count == 5 || players.filter({ !$0.hasFolded }).count == 1 else { return }
        street = .showdown
        withAnimation(.spring(response: 0.45)) {
            revealCPUHole = true
            isShowdown = true
            handEnded = true
        }
    }

    func isHandInAllInState() -> Bool {
        let active = players.filter { !$0.hasFolded }
        return active.count == 2 && active.allSatisfy { $0.isAllIn }
    }

    func revealAllBoardAndShowdown() {
        func delay(_ sec: Double, _ action: @Sendable @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + sec, execute: action)
        }
        delay(0.5) { Task { @MainActor in self.revealFlop() } }
        delay(1.2) { Task { @MainActor in self.revealTurn() } }
        delay(1.9) { Task { @MainActor in self.revealRiver() } }
        delay(2.6) { Task { @MainActor in self.goToShowdown() } }
    }

    func myBestHandName() -> String {
        return bestHandName(forPlayerAt: 0)
    }

    func cpuBestHandName() -> String {
        return bestHandName(forPlayerAt: 1)
    }

    func currentBestHandName(for playerIndex: Int) -> String {
        guard players.indices.contains(playerIndex) else { return "-" }
        let hole = players[playerIndex].holeCards
        let community = board
        let total = hole.count + community.count
        guard total >= 5 else { return "役評価中" }

        let score = evaluateBest5(from: hole + community)
        return name(of: score.category)
    }

    private func bestHandName(forPlayerAt index: Int) -> String {
        guard players.indices.contains(index) else { return "-" }
        let hole = players[index].holeCards
        let community = board
        let total = hole.count + community.count
        guard total >= 5 else { return "役評価中" }

        let score = evaluateBest5(from: hole + community)
        return name(of: score.category)
    }

    func showdownResultText() -> String {
        guard players.count >= 2, board.count == 5 else {
            return "ボードが5枚公開されていません"
        }
        let a = players[0].holeCards
        let b = players[1].holeCards
        let result = compareHeadsUp(holeA: a, holeB: b, board: board)
        switch result {
        case .leftWins: return "You の勝ち"
        case .rightWins: return "CPU の勝ち"
        case .split: return "スプリット（引き分け）"
        }
    }

    func isHighlightedCard(_ card: Card, for playerIndex: Int? = nil) -> Bool {
        guard isShowdown, players.count >= 2, board.count == 5 else { return false }

        let a = evaluateBest5(from: players[0].holeCards + board)
        let b = evaluateBest5(from: players[1].holeCards + board)
        let result = compareHeadsUp(holeA: players[0].holeCards, holeB: players[1].holeCards, board: board)

        switch result {
        case .leftWins:
            return a.cards.contains(card)
        case .rightWins:
            return b.cards.contains(card)
        case .split:
            return false
        }
    }

    private func name(of cat: HandCategory) -> String {
        switch cat {
        case .royalFlush: return "ロイヤルストレートフラッシュ"
        case .straightFlush: return "ストレートフラッシュ"
        case .fourOfAKind: return "フォーカード"
        case .fullHouse: return "フルハウス"
        case .flush: return "フラッシュ"
        case .straight: return "ストレート"
        case .threeOfAKind: return "スリーカード"
        case .twoPair: return "ツーペア"
        case .onePair: return "ワンペア"
        case .highCard: return "ハイカード"
        }
    }
}
