import SwiftUI

@main
struct MyHTMLAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            Text("ホーム画面")
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }

            Text("さがす画面")
                .tabItem {
                    Label("さがす", systemImage: "magnifyingglass")
                }

            Text("ランキング画面")
                .tabItem {
                    Label("ランキング", systemImage: "trophy.fill")
                }

            Text("マイページ画面")
                .tabItem {
                    Label("マイページ", systemImage: "person.fill")
                }

            Text("設定画面")
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
    }
}
