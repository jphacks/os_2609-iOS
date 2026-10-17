//
//  CaptureResultComponent.swift
//  ARApp
//

import SwiftUI

/// 捕獲の結果（成功・失敗）を AR の上に重ねて出す
/// 【仮】見た目は仮
struct CaptureResultComponent: View {
    let outcome: ARCaptureViewModel.CaptureOutcome

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isSuccess ? "checkmark.seal.fill" : "xmark.octagon.fill")
                .font(.system(size: 64))
                .foregroundStyle(isSuccess ? .yellow : .gray)
            Text(isSuccess ? "捕獲成功！" : "捕獲失敗…")
                .font(.largeTitle.bold())
            Text(message)
                .font(.headline)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var isSuccess: Bool {
        if case .success = outcome { true } else { false }
    }

    private var message: String {
        switch outcome {
        case .success(let monster): "\(monster.name)を捕まえた！"
        case .failure(let monster): "\(monster.name)に逃げられた…"
        }
    }
}

#Preview("成功") {
    CaptureResultComponent(outcome: .success(Monster.all[0]))
}

#Preview("失敗") {
    CaptureResultComponent(outcome: .failure(Monster.all[0]))
}
