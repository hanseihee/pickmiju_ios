import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://oowzvdlykxvnmyjxrghr.supabase.co")!
    // TODO: Supabase 대시보드 → Settings → API → anon public 키를 입력하세요
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9vd3p2ZGx5a3h2bm15anhyZ2hyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1MjI2ODgsImV4cCI6MjA4MzA5ODY4OH0.LqXXd7KtuEVclIpnNWK0VtKUNrTsHMwyUaikQi-zRHE"
    static let redirectURL = URL(string: "pickmiju://auth/callback")!
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey,
    options: .init(
        auth: .init(
            redirectToURL: SupabaseConfig.redirectURL,
            emitLocalSessionAsInitialSession: true
        )
    )
)
