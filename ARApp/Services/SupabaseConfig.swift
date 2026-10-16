//
//  SupabaseConfig.swift
//  ARApp
//

/// Supabase プロジェクトの接続先
/// ダッシュボードの Project Settings → API にある値を書く
/// anon key はアプリに入れて配る前提の公開用の鍵なので、コミットしてよい
enum SupabaseConfig {
    /// Project URL（例："https://xxxx.supabase.co"）
    static let url = ""
    /// anon（public）key
    static let anonKey = ""

    /// 値が入っていなければ、ContentView は DummyBattleService を使う
    static var isConfigured: Bool { !url.isEmpty && !anonKey.isEmpty }
}
