//
//  BattleSoundPlayer.swift
//  ARApp
//

import AVFoundation

/// バトルの効果音を鳴らす
/// 音のファイルは使わず、起動してから最初に鳴らすときに、音をその場で作る
/// 消音モード（本体の横のスイッチ）のときは鳴らない。ほかのアプリの音楽は止めずに重ねて鳴らす
final class BattleSoundPlayer {
    enum Sound {
        /// 通常攻撃が当たった
        case hit
        /// フィーバー中の通常攻撃が当たった
        case feverHit
        /// 必殺技が当たった
        case specialHit
        /// とどめを刺した
        case finishHit
        /// フィーバーが始まった
        case feverStart
        /// 相手の必殺技の予告
        case danger
        /// 勝った
        case victory
    }

    /// 対戦ごとに作り直さないよう、アプリ全体で 1 つだけ使う
    static let shared = BattleSoundPlayer()

    private static let sampleRate = 44_100.0
    private static let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

    private let engine = AVAudioEngine()
    /// 攻撃の音と、それ以外（予告や勝利）の音。分けておくと、連打していても予告や勝利の音が途中で切れない
    private let hitPlayer = AVAudioPlayerNode()
    private let jinglePlayer = AVAudioPlayerNode()
    /// 通常攻撃の音。毎回同じ音だと単調なので、高さを少しずつ変えたものを用意して、順に鳴らす
    private let normalHits = [1.0, 1.12, 0.92].map { BattleSoundPlayer.makeHit(pitch: $0, length: 0.12, decay: 30) }
    /// フィーバー中は、高く明るい音にキラッとした音を重ねる
    private let feverHits = [1.4, 1.55, 1.3].map { BattleSoundPlayer.makeHit(pitch: $0, length: 0.18, decay: 25, sparkle: 1800) }
    /// 必殺技の音。低く、長く響かせる
    private let specialHit = BattleSoundPlayer.makeHit(pitch: 0.7, length: 0.35, decay: 10)
    /// とどめの音。さらに低く、長く響かせる
    private let finishHit = BattleSoundPlayer.makeHit(pitch: 0.5, length: 0.8, decay: 5, sparkle: 1200)
    /// フィーバー開始：ドミソドと駆け上がる
    private let feverStart = BattleSoundPlayer.makeMelody([(523, 0.07), (659, 0.07), (784, 0.07), (1047, 0.35)])
    /// 予告：高い音と低い音を 2 回くり返す警報
    private let danger = BattleSoundPlayer.makeMelody([(880, 0.12), (660, 0.12), (880, 0.12), (660, 0.2)], wave: .square)
    /// 勝利：ファンファーレ
    private let victory = BattleSoundPlayer.makeMelody([(523, 0.12), (523, 0.12), (523, 0.12), (659, 0.3), (587, 0.15), (784, 0.7)])
    private var nextHit = 0

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        for player in [hitPlayer, jinglePlayer] {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: Self.format)
        }
    }

    func play(_ sound: Sound) {
        // 電話がかかってきたときなどにエンジンが止まるので、止まっていたら動かし直す
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                return
            }
        }

        let (player, buffer): (AVAudioPlayerNode, AVAudioPCMBuffer)
        switch sound {
        case .hit: (player, buffer) = (hitPlayer, nextBuffer(of: normalHits))
        case .feverHit: (player, buffer) = (hitPlayer, nextBuffer(of: feverHits))
        case .specialHit: (player, buffer) = (hitPlayer, specialHit)
        case .finishHit: (player, buffer) = (hitPlayer, finishHit)
        case .feverStart: (player, buffer) = (jinglePlayer, feverStart)
        case .danger: (player, buffer) = (jinglePlayer, danger)
        case .victory: (player, buffer) = (jinglePlayer, victory)
        }
        if !player.isPlaying { player.play() }
        // 前の音が残っていたら止めて、すぐに鳴らす
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
    }

    private func nextBuffer(of buffers: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer {
        nextHit = (nextHit + 1) % buffers.count
        return buffers[nextHit]
    }

    /// 打撃音を作る。低い「ドッ」と短い「パシッ」を重ねる
    /// pitch を大きくすると高い音、decay を大きくすると早く消える音になる。sparkle を渡すと、その高さのキラッとした音を重ねる
    private static func makeHit(pitch: Double, length: Double, decay: Double, sparkle: Double? = nil) -> AVAudioPCMBuffer {
        makeBuffer(length: length) { t in
            // 低い「ドッ」：高い音から低い音へ一気に下げる。音の高さが変わるので、高さを足し合わせて位相にする
            let phase = 2 * .pi * pitch * (70 * t + 160 * (1 - exp(-t * 40)) / 40)
            let thump = sin(phase) * exp(-t * decay)
            // 短い「パシッ」：ノイズをすぐに消す
            let crack = Double.random(in: -1...1) * exp(-t * 90)
            let shine = sparkle.map { sin(2 * .pi * $0 * t) * 0.3 * exp(-t * 15) } ?? 0
            return (0.7 * thump + 0.45 * crack + shine) * 0.8
        }
    }

    private enum Wave {
        case sine
        case square
    }

    /// 音の高さ（Hz）と長さ（秒）の並びから、短いメロディを作る
    private static func makeMelody(_ notes: [(frequency: Double, length: Double)], wave: Wave = .sine) -> AVAudioPCMBuffer {
        let starts = notes.reduce(into: [0.0]) { $0.append($0.last! + $1.length) }
        return makeBuffer(length: starts.last!) { t in
            guard let index = starts.lastIndex(where: { $0 <= t }), index < notes.count else { return 0 }
            let note = notes[index]
            let local = t - starts[index]
            let tone = sin(2 * .pi * note.frequency * local)
            let shaped = switch wave {
            case .sine: tone + 0.3 * sin(4 * .pi * note.frequency * local) // 倍音を足して明るくする
            case .square: tone >= 0 ? 0.5 : -0.5
            }
            // 音ごとに、鳴り始めと終わりで音を小さくして、つなぎ目でプツッと鳴らないようにする
            let envelope = min(local / 0.005, 1) * min((note.length - local) / 0.02, 1)
            return shaped * envelope * 0.35
        }
    }

    /// 時刻（秒）ごとの音の大きさ（-1〜1）から、音のデータを作る
    private static func makeBuffer(length: Double, sample: (Double) -> Double) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(length * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            // 鳴り始めにプツッと音が出ないよう、最初の 2ms で音を大きくする
            let attack = min(t / 0.002, 1)
            samples[i] = Float(max(-1, min(sample(t) * attack, 1)))
        }
        return buffer
    }
}
