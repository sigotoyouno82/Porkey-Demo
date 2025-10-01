import SwiftUI
import Combine

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

struct MainContentView: View {
    @StateObject var vm = GameVM()
    @State private var potChips: [UUID] = []

    // Raise UI
    @State private var raiseAmount: Int = 20
    private let minRaise: Int = 20
    private var isMyTurn: Bool { vm.currentPlayerIndex == 0 && !vm.isShowdown && !vm.handEnded }
    private var callTitle: String { vm.callAmount > 0 ? "コール \(vm.callAmount)" : "チェック" }

    // 表示演出
    @State private var showButtons = false
    @State private var showHandLabels = false
    @State private var cpuActionText: String? = nil
    @State private var cancellables = Set<AnyCancellable>()

    // チップアニメーション
        @State private var animateChipToPot = false
        @State private var chipOffset: CGFloat = 0

        var body: some View {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.green.opacity(0.9), Color.green]),
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)

                    Spacer()

                    cpuSection
                    boardSection
                    potChipStack
                    Spacer()
                    myCardsSection
                    Spacer()
                    actionOrNextHandButton
                    showdownInfo
                    Spacer()
                }
                .padding()
                .onAppear {
                    withAnimation(.easeOut(duration: 0.5)) { showButtons = true }
                    let yourChips = vm.players.indices.contains(0) ? vm.players[0].chips : 0
                    raiseAmount = min(max(minRaise, vm.callAmount + minRaise), max(0, yourChips))


                    // ✅ CPUアクション受信
                    vm.cpuActionSubject
                        .sink { text in
                            cpuActionText = text

                            // ✅ アクション内容によってチップ追加
                            if text == "ベット" || text == "コール" || text == "レイズ" {
                                addChipToPot()
                            }

                            // ✅ 表示後1.6秒で非表示
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                withAnimation {
                                    cpuActionText = nil
                                }
                            }
                        }
                        .store(in: &cancellables)
                }
                .onChange(of: vm.isShowdown) { oldValue, newValue in
                    if newValue { showHandLabels = true }
                }

                // ✅ アニメーション用チップ（中央へ移動）
                if animateChipToPot {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 24, height: 24)
                        .overlay(Text("💰").font(.caption))
                        .offset(y: chipOffset)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                chipOffset = -200
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                animateChipToPot = false
                                chipOffset = 0
                                        }
                                    }
                            }
                // ✅ CPUのアクション表示（通知風）
                           if let action = cpuActionText {
                               Text("CPU: \(action)")
                                   .font(.headline)
                                   .padding(10)
                                   .background(Color.black.opacity(0.7))
                                   .foregroundColor(.white)
                                   .cornerRadius(12)
                                   .transition(.move(edge: .top).combined(with: .opacity))
                                   .zIndex(10)
                                   .padding(.top, 40)
                           }
            }
        }
    
    // ✅ ポットのチップ表示
        var potChipStack: some View {
            let columns = Array(repeating: GridItem(.fixed(20), spacing: 4), count: 5)
            return LazyVGrid(columns: columns, spacing: 4) {
                ForEach(potChips, id: \.self) { _ in
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 20, height: 20)
                        .shadow(radius: 1)
                }
            }
        }
    
    private func addChipToPot(count: Int = 1) {
        withAnimation(.easeOut(duration: 0.4)) {
            for _ in 0..<count {
                potChips.append(UUID())
            }
        }
    }

    // MARK: - CPU セクション
    var cpuSection: some View {
        VStack(spacing: 4) {
            HStack {
                ForEach(vm.players.indices.contains(1) ? vm.players[1].holeCards : [], id: \.self) { card in
                    MiniCardView(
                        card: card,
                        faceUp: vm.revealCPUHole,
                        highlighted: vm.isShowdown ? vm.isHighlightedCard(card, for: 1) : false
                    )
                }
            }
            if let action = cpuActionText {
                Text(action)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 4)
                    .transition(.opacity)
            }
            Text("CPU").foregroundColor(.red)
        }
        .padding(.top, 30)
    }

    // MARK: - ボードセクション
    var boardSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(vm.board, id: \.self) { card in
                    MiniCardView(
                        card: card,
                        highlighted: vm.isShowdown ? vm.isHighlightedCard(card) : false
                    )
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .shadow(radius: 5)
            )

            HStack(spacing: 12) {
                Text("Pot: \(vm.pot)").foregroundColor(.white)
                if vm.players.indices.contains(0) {
                    Text("Your Chips: \(vm.players[0].chips)").foregroundColor(.yellow)
                }
                if vm.players.indices.contains(1) {
                    Text("CPU Chips: \(vm.players[1].chips)").foregroundColor(.red)
                }
                if vm.currentBet > 0 {
                    Text("Current Bet: \(vm.currentBet)").foregroundColor(.white.opacity(0.9))
                }
            }
            .font(.subheadline)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - プレイヤーの手札
    var myCardsSection: some View {
        VStack(spacing: 4) {
            HStack {
                ForEach(vm.players.indices.contains(0) ? vm.players[0].holeCards : [], id: \.self) { card in
                    MiniCardView(
                        card: card,
                        faceUp: true,
                        highlighted: vm.isShowdown ? vm.isHighlightedCard(card, for: 0) : false
                    )
                }
            }
            Text("You").foregroundColor(.yellow)
        }
    }

    // MARK: - アクションバー or 次のハンド
    var actionOrNextHandButton: some View {
        Group {
            if !vm.isShowdown && !vm.isHandInAllInState() && vm.players.filter({ !$0.hasFolded }).count > 1 {
                actionBar
            } else {
                Button("新しいハンド") {
                    vm.startNewPracticeHand()
                    showHandLabels = false
                    potChips.removeAll()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(16)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - 勝敗結果とハンド名
    var showdownInfo: some View {
        VStack(spacing: 6) {
            Text("あなた：\(vm.isShowdown ? vm.myBestHandName() : vm.currentBestHandName(for: 0))")
                .foregroundColor(.yellow)
                .bold()
                .opacity(vm.isShowdown && !showHandLabels ? 0 : 1)

            Text(vm.isShowdown ? "CPU：\(vm.cpuBestHandName())" : "CPU：？？？")
                .foregroundColor(.red)
                .bold()
                .opacity(vm.isShowdown && !showHandLabels ? 0 : 1)

            if vm.isShowdown {
                Text(vm.showdownResultText())
                    .font(.title3)
                    .bold()
                    .foregroundColor(.orange)
                    .padding(.top, 6)
                    .opacity(showHandLabels ? 1 : 0)
                    .offset(y: showHandLabels ? 0 : 10)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: showHandLabels)
            }
        }
    }

    // MARK: - アクションバー
    var actionBar: some View {
        let callAmount = vm.callAmount
        let youChips = vm.players.indices.contains(0) ? vm.players[0].chips : 0
        let maxRaise = max(0, youChips)

        return VStack(spacing: 10) {
            Text("あなたのターン")
                .font(.headline)
                .padding(6)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(8)

            HStack(spacing: 10) {
                Button("フォールド") {
                    vm.performAction(.fold)
                }.buttonStyle(.bordered).tint(.gray)

                Button(callAmount > 0 ? "コール \(callAmount)" : "チェック") {
                    animateChipToPot = true
                    vm.performAction(callAmount > 0 ? .call : .check)
                    if callAmount > 0 { addChipToPot() }
                }.buttonStyle(.borderedProminent).tint(.blue)

                Button("オールイン") {
                    animateChipToPot = true
                    vm.performAction(.allIn)
                    addChipToPot(count: 3)
                }.buttonStyle(.bordered).tint(.red)
            }

            HStack(spacing: 12) {
                ForEach([2, 3], id: \.self) { multiplier in
                    Button("×\(multiplier)") {
                        let base = max(vm.currentBet - vm.players[0].currentBet, minRaise)
                        raiseAmount = min(maxRaise, base * multiplier)
                    }
                    .frame(width: 60, height: 40)
                    .background(Color.white)
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                }
                Button("ポット") {
                    let estimatedPot = vm.pot + callAmount
                    raiseAmount = min(maxRaise, estimatedPot)
                }
                .frame(width: 60, height: 40)
                .background(Color.white)
                .foregroundColor(.blue)
                .cornerRadius(10)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("レイズ額: \(raiseAmount)")
                    .foregroundColor(.white)
                    .font(.subheadline)

                if youChips >= minRaise {
                    Slider(
                        value: Binding(
                            get: { Double(raiseAmount) },
                            set: { newVal in
                                raiseAmount = min(youChips, max(minRaise, Int(newVal)))
                            }
                        ),
                        in: Double(minRaise)...Double(youChips),
                        step: Double(minRaise)
                    )
                    .disabled(!isMyTurn)
                    .accentColor(.blue)
                } else {
                    Text("残高不足のためレイズ不可")
                        .foregroundColor(.gray)
                        .italic()
                }

                HStack(spacing: 12) {
                    Button("+\(minRaise)") {
                        raiseAmount = min(youChips, raiseAmount + minRaise)
                    }
                    Button("Min") {
                        raiseAmount = min(youChips, max(minRaise, callAmount + minRaise))
                    }
                    Button("ベット \(raiseAmount)") {
                        animateChipToPot = true
                        vm.performAction(.raise(amount: raiseAmount))
                        addChipToPot(count: 2)
                    }
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(10)
                    .frame(height: 44)
                    .disabled(!(isMyTurn && raiseAmount > vm.callAmount && youChips >= minRaise))
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.2))
            )
            .padding(.horizontal)
        }
    }
}
