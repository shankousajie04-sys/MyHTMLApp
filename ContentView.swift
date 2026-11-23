import SwiftUI

@main
struct MyHTMLAppApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct AppItem: Identifiable, Hashable {
    let id: String, name: String, desc: String, cat: String, icon: String, color: Color, isGame: Bool
}

let apps = [
    AppItem(id: "1", name: "Block Breaker", desc: "爽快ネオンブロック崩し", cat: "アクション", icon: "gamecontroller.fill", color: .purple, isGame: true),
    AppItem(id: "2", name: "Pixel Synth", desc: "8bit作曲・効果音スタジオ", cat: "音楽", icon: "waveform", color: .orange, isGame: false),
    AppItem(id: "3", name: "Dash Runner", desc: "リズムに乗って障害物を飛べ", cat: "リズム", icon: "bolt.fill", color: .blue, isGame: true),
    AppItem(id: "4", name: "Snap Canvas", desc: "軽量ドット絵＆イラストメモ", cat: "お絵描き", icon: "paintbrush.fill", color: .pink, isGame: false),
    AppItem(id: "5", name: "Code Pocket", desc: "Swift・HTMLコードメモ帳", cat: "開発", icon: "chevron.left.forwardslash.chevron.right", color: .teal, isGame: false)
]

struct ContentView: View {
    @AppStorage("saved") private var savedStr = ""
    var saved: Set<String> { Set(savedStr.split(separator: ",").map(String.init)) }
    func toggle(_ id: String) {
        var s = saved
        if s.contains(id) { s.remove(id) } else { s.insert(id) }
        savedStr = s.joined(separator: ",")
    }

    var body: some View {
        TabView {
            AppListView(title: "おすすめ", list: apps, saved: saved, toggle: toggle)
                .tabItem { Label("おすすめ", systemImage: "star.fill") }
            AppListView(title: "ゲーム", list: apps.filter { $0.isGame }, saved: saved, toggle: toggle)
                .tabItem { Label("ゲーム", systemImage: "gamecontroller.fill") }
            AppListView(title: "アプリ", list: apps.filter { !$0.isGame }, saved: saved, toggle: toggle)
                .tabItem { Label("アプリ", systemImage: "square.stack.3d.up.fill") }
            SearchTab(saved: saved, toggle: toggle)
                .tabItem { Label("検索", systemImage: "magnifyingglass") }
            AppListView(title: "保存済み", list: apps.filter { saved.contains($0.id) }, saved: saved, toggle: toggle)
                .tabItem { Label("保存済み", systemImage: "bookmark.fill") }
        }
    }
}

struct AppListView: View {
    let title: String, list: [AppItem], saved: Set<String>, toggle: (String) -> Void

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                rows
                    .navigationTitle(title)
                    .navigationDestination(for: AppItem.self) { item in
                        AppDetailView(item: item, saved: saved, toggle: toggle)
                    }
            }
        } else {
            NavigationView {
                rows
                    .navigationTitle(title)
            }
            .navigationViewStyle(.stack)
        }
    }

    private var rows: some View {
        List(list) { item in
            HStack(spacing: 12) {
                destinationLink(for: item) {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(item.color)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading) {
                            Text(item.name).font(.headline)
                            Text(item.desc).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                Button(saved.contains(item.id) ? "保存済" : "入手") { toggle(item.id) }
                    .buttonStyle(.bordered)
                    .tint(saved.contains(item.id) ? .gray : .blue)
            }
        }
    }

    @ViewBuilder
    private func destinationLink<Label: View>(for item: AppItem, @ViewBuilder label: () -> Label) -> some View {
        if #available(iOS 16.0, *) {
            NavigationLink(value: item, label: label)
        } else {
            NavigationLink(destination: AppDetailView(item: item, saved: saved, toggle: toggle), label: label)
        }
    }
}

struct AppDetailView: View {
    let item: AppItem, saved: Set<String>, toggle: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: item.icon)
                .font(.largeTitle)
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(item.color)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            Text(item.name).font(.title.bold())
            Text(item.cat)
                .font(.caption)
                .padding(6)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
            Text(item.desc).foregroundColor(.secondary)
            Button(saved.contains(item.id) ? "保存済み" : "入手する") { toggle(item.id) }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct SearchTab: View {
    @State private var text = ""
    @State private var cat = "すべて"
    let saved: Set<String>, toggle: (String) -> Void
    let cats = ["すべて", "アクション", "リズム", "音楽", "お絵描き", "開発"]

    var body: some View {
        let filtered = apps.filter {
            (cat == "すべて" || $0.cat == cat) &&
            (text.isEmpty || $0.name.localizedCaseInsensitiveContains(text))
        }
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(cats, id: \.self) { c in
                        Button(c) { cat = c }
                            .buttonStyle(.borderedProminent)
                            .tint(cat == c ? .blue : .gray)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            AppListView(title: "検索", list: filtered, saved: saved, toggle: toggle)
        }
        .searchable(text: $text, prompt: "アプリ名で検索")
    }
}
