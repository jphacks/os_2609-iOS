//
//  TimingGauge.swift
//  ARApp
//

import Foundation

/// ゲージ上の判定エリア 1 つ。位置は 0 が左端、1 が右端
struct TimingZone {
    /// PERFECT の幅が GOOD の幅に占める割合
    static let perfectRatio = 0.4

    /// GOOD になる範囲
    let goodRange: ClosedRange<Double>
    /// PERFECT になる範囲（goodRange の真ん中）
    let perfectRange: ClosedRange<Double>

    init(center: Double, width: Double) {
        goodRange = (center - width / 2)...(center + width / 2)
        let perfectWidth = width * Self.perfectRatio
        perfectRange = (center - perfectWidth / 2)...(center + perfectWidth / 2)
    }

    func judge(position: Double) -> TimingJudgement {
        if perfectRange.contains(position) { return .perfect }
        if goodRange.contains(position) { return .good }
        return .miss
    }
}

/// 1 ターンぶんのゲージ。カーソルの位置と判定を経過時間だけから計算する
/// UI にも現在時刻にも依存しないので、将来バトル状態を同期するときも同じ計算を使える
struct TimingGauge {
    /// カーソルが左端から右端まで進むのにかかる時間（秒）
    let traverseDuration: TimeInterval
    /// 判定エリア。左から順に並び、この順に当てていく
    let zones: [TimingZone]

    /// 経過時間に対するカーソルの位置。0 が左端、1 が右端
    /// カーソルは 1 回だけ流れ、右端で止まる
    func cursorPosition(elapsed: TimeInterval) -> Double {
        min(max(elapsed / traverseDuration, 0), 1)
    }

    /// STOP を押した瞬間の経過時間から判定する
    /// カーソルがどれかのエリアに入っていれば、そのエリアの番号と判定を返す。どこにも入っていなければ nil（MISS）
    func judge(elapsed: TimeInterval) -> (zoneIndex: Int, judgement: TimingJudgement)? {
        let position = cursorPosition(elapsed: elapsed)
        guard let zoneIndex = zones.firstIndex(where: { $0.goodRange.contains(position) }) else { return nil }
        return (zoneIndex, zones[zoneIndex].judge(position: position))
    }
}

extension TimingGauge {
    /// 判定エリアを置く範囲。左端すぐだと反応できないので少し空ける
    private static let zoneArea = 0.12...0.98

    /// 1 ターンぶんのゲージを作る。判定エリアは毎ターンランダムな位置に置く
    /// モンスターが怒っているとカーソルが速く、エリアが狭くなる
    /// 乱数を外から渡せるので、将来は同じ seed を共有すれば全員が同じゲージを作れる
    static func random(
        profile: BattleProfile,
        attackType: AttackType,
        isEnraged: Bool,
        using generator: inout some RandomNumberGenerator
    ) -> TimingGauge {
        let duration = profile.traverseDuration * (isEnraged ? 0.75 : 1)
        let width = profile.zoneWidth * attackType.zoneWidthMultiplier * (isEnraged ? 0.8 : 1)

        // 範囲をエリアの数で等分し、各区間の中に 1 つずつ置く（重ならない）
        let segmentWidth = (zoneArea.upperBound - zoneArea.lowerBound) / Double(profile.zoneCount)
        let zones = (0..<profile.zoneCount).map { index in
            let segmentStart = zoneArea.lowerBound + segmentWidth * Double(index)
            let centerRange = (segmentStart + width / 2)...(segmentStart + segmentWidth - width / 2)
            return TimingZone(center: Double.random(in: centerRange, using: &generator), width: width)
        }
        return TimingGauge(traverseDuration: duration, zones: zones)
    }
}
