//
//  LocalAIOpponent.swift
//  ARApp
//

/// 端末の中で動く敵 AI。一定間隔で通常攻撃するだけ
struct LocalAIOpponent: BattleOpponent {
    let fighter = RealtimeFighter(id: "local-ai", name: "ドラゴン", maxHP: 300)
    /// 攻撃する間隔（秒）
    var attackInterval: Double = 2

    func actions() -> AsyncStream<BattleAction> {
        let interval = attackInterval
        return AsyncStream { continuation in
            let task = Task {
                while true {
                    do {
                        try await Task.sleep(for: .seconds(interval))
                    } catch {
                        break // キャンセルされた
                    }
                    continuation.yield(.normalAttack)
                }
                continuation.finish()
            }
            // 受け取る側が止まったら（画面が消えた、決着した）タイマーも止める
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func send(_ action: BattleAction) {
        // AI はこちらの行動を受け取る必要がない
    }
}
