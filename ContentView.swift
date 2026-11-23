import SwiftUI

@main
struct MyHTMLAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - データモデル（アプリ情報）
struct AppItem: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let category: String
    let rating: Double
    let iconName: String
    let iconColor: Color
    let description: String
    let isGame: Bool
}

// サンプルのアプリ一覧データ
let sampleApps: [AppItem] = [
    AppItem(
        id: "1",
        name: "Block Breaker Neo",
        subtitle: "爽快ネオンブロック崩し",
        category: "アクション",
        rating: 4.8,
        iconName: "gamecontroller.fill",
        iconColor: .purple,
        description: "指1本で遊べるハイスピードなブロック崩しゲーム。多彩なステージとパワーアップアイテムを搭載。",
        isGame: true
    ),
    AppItem(
        id: "2",
        name: "Pixel Synth",
        subtitle: "ポケット作曲・効果音スタジオ",
        category: "ミュージック",
        rating: 4.9,
        iconName: "waveform",
        iconColor: .orange,
        description: "8ビット風のレトロな効果音やBGMを直感的に作成・書き出しできるサウンドツール。",
        isGame: false
    ),
    AppItem(
        id: "3",
        name: "Dash Runner",
        subtitle: "リズムに乗って障害物を飛び越えろ",
        category: "リズム",
        rating: 4.7,
        iconName: "bolt.fill",
        iconColor: .blue,
        description: "音楽に合わせてジャンプする高難易度アクション。自作ステージの共有にも対応。",
        isGame: true
    ),
    AppItem(
        id: "4",
        name: "Snap Canvas",
        subtitle: "シンプルお絵描き＆ドット絵メモ",
        category: "グラフィック",
        rating: 4.6,
        iconName: "paintbrush.fill",
        iconColor: .pink,
        description: "起動してすぐに描き始められる軽量イラストアプリ。レイヤー機能や透過PNG保存に対応。",
        isGame: false
    ),
    AppItem(
        id: "5",
        name: "Code Pocket",
        subtitle: "スマホで始めるコードスニペット帳",
        category: "開発ツール",
        rating: 4.9,
        iconName: "chevron.left.forwardslash.chevron.right",
        iconColor: .teal,
        description: "よく使うSwiftやHTMLのコードをタグ付きで整理・コピーできるプログラマー向けメモ。",
        isGame: false
    ),
    AppItem(
        id: "6",
        name: "Cyber Maze",
        subtitle: "無限生成ダンジョン探索",
        category: "パズル",
        rating: 4.5,
        iconName: "square.grid.3x3.fill",
        iconColor: .indigo,
        description: "毎回形が変わる迷路を攻略する頭脳派パズルゲーム。",
        isGame: true
    )
]

// MARK: - メインの5タブ画面
struct ContentView: View {
    @AppStorage("savedAppIDs") private var savedIDsString = ""

    var savedIDs: Set<String> {
        Set(savedIDsString.split(separator: ",").map(String.init))
    }

    func toggleSave(_ id: String) {
        var current = savedIDs
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
        }
        savedIDsString = current.joined(separator: ",")
    }

    var body: some View {
        TabView {
            TodayView(savedIDs: savedIDs, onToggleSave: toggleSave)
                .tabItem {
                    Label("おすすめ", systemImage: "star.fill")
                }

            CategoryListView(
                title: "ゲーム",
                apps: sampleApps.filter { $0.isGame },
                savedIDs: savedIDs,
                onToggleSave: toggleSave
            )
            .tabItem {
                Label("ゲーム", systemImage: "gamecontroller.fill")
            }

            CategoryListView(
                title: "アプリ",
                apps: sampleApps.filter { !$0.isGame },
                savedIDs: savedIDs,
                onToggleSave: toggleSave
            )
            .tabItem {
                Label("アプリ", systemImage: "square.stack.3d.up.fill")
            }

            SearchView(savedIDs: savedIDs, onToggleSave: toggleSave)
                .tabItem {
                    Label("検索", systemImage: "magnifyingglass")
                }

            SavedAppsView(savedIDs: savedIDs, onToggleSave: toggleSave)
                .tabItem {
                    Label("保存済み", systemImage: "bookmark.fill")
                }
        }
    }
}

// MARK: - 1. おすすめタブ
struct TodayView: View {
    let savedIDs: Set<String>
    let onToggleSave: (String) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let featured = sampleApps.first {
                        NavigationLink(value: featured) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("本日のピックアップ")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white.opacity(0.8))

                                HStack(spacing: 16) {
                                    AppIconView(iconName: featured.iconName, color: .white, backgroundColor: .white.opacity(0.2), size: 64)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(featured.name)
                                            .font(.title2.bold())
                                            .foregroundStyle(.white)
                                        Text(featured.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.9))
                                    }
                                    Spacer()
                                }
                            }
                            .padding(20)
                            .background(
                                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("人気のアプリ")
                            .font(.title3.bold())

                        ForEach(sampleApps) { app in
                            AppRowView(
                                app: app,
                                isSaved: savedIDs.contains(app.id),
                                onToggleSave: { onToggleSave(app.id) }
                            )
                            Divider()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("おすすめ")
            .navigationDestination(for: AppItem.self) { app in
                AppDetailView(app: app, isSaved: savedIDs.contains(app.id), onToggleSave: { onToggleSave(app.id) })
            }
        }
    }
}

// MARK: - 2 & 3. ゲーム / アプリ一覧タブ
struct CategoryListView: View {
    let title: String
    let apps: [AppItem]
    let savedIDs: Set<String>
    let onToggleSave: (String) -> Void

    var body: some View {
        NavigationStack {
            List(apps) { app in
                AppRowView(
                    app: app,
                    isSaved: savedIDs.contains(app.id),
                    onToggleSave: { onToggleSave(app.id) }
                )
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
            .listStyle(.plain)
            .navigationTitle(title)
            .navigationDestination(for: AppItem.self) { app in
                AppDetailView(app: app, isSaved: savedIDs.contains(app.id), onToggleSave: { onToggleSave(app.id) })
            }
        }
    }
}

// MARK: - 4. 検索タブ
struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedCategory = "すべて"
    let savedIDs: Set<String>
    let onToggleSave: (String) -> Void

    let categories = ["すべて", "アクション", "リズム", "パズル", "ミュージック", "グラフィック", "開発ツール"]

    var filteredApps: [AppItem] {
        sampleApps.filter { app in
            let matchesCategory = (selectedCategory == "すべて") || (app.category == selectedCategory)
            let matchesText = searchText.isEmpty ||
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.subtitle.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesText
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category)
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == category ? Color.blue : Color(.secondarySystemBackground))
                                    .foregroundStyle(selectedCategory == category ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }

                List(filteredApps) { app in
                    AppRowView(
                        app: app,
                        isSaved: savedIDs.contains(app.id),
                        onToggleSave: { onToggleSave(app.id) }
                    )
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }
                .listStyle(.plain)
            }
            .navigationTitle("アプリを探す")
            .searchable(text: $searchText, prompt: "アプリ名・キーワードを入力")
            .navigationDestination(for: AppItem.self) { app in
AppDetailView(app: app, isSaved: savedIDs.contains(app.id), onToggleSave: { onToggleSave(app.id) })
}
}
}
}
// MARK: - 5. 保存済みタブ
struct SavedAppsView: View {
let savedIDs: Set
let onToggleSave: (String) -> Void
var savedApps: [AppItem] {
sampleApps.filter { savedIDs.contains($0.id) }
}
var body: some View {
NavigationStack {
if savedApps.isEmpty {
VStack(spacing: 12) {
Image(systemName: "bookmark.slash")
.font(.system(size: 50))
.foregroundStyle(.secondary)
Text("保存したアプリはありません")
.font(.headline)
Text("気になるアプリの「入手」ボタンを押すとここに追加されます")
.font(.caption)
.foregroundStyle(.secondary)
.multilineTextAlignment(.center)
}
.padding()
.navigationTitle("保存済み")
} else {
List(savedApps) { app in
AppRowView(
app: app,
isSaved: true,
onToggleSave: { onToggleSave(app.id) }
)
.listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
}
.listStyle(.plain)
.navigationTitle("保存済み")
.navigationDestination(for: AppItem.self) { app in
AppDetailView(app: app, isSaved: true, onToggleSave: { onToggleSave(app.id) })
}
}
}
}
}
// MARK: - 共通部品：アプリの1行表示
struct AppRowView: View {
let app: AppItem
let isSaved: Bool
let onToggleSave: () -> Void
var body: some View {
HStack(spacing: 14) {
NavigationLink(value: app) {
HStack(spacing: 14) {
AppIconView(iconName: app.iconName, color: .white, backgroundColor: app.iconColor, size: 54)
VStack(alignment: .leading, spacing: 4) {
Text(app.name)
.font(.headline)
.foregroundStyle(.primary)
Text(app.subtitle)
.font(.caption)
.foregroundStyle(.secondary)
.lineLimit(1)
HStack(spacing: 4) {
Image(systemName: "star.fill")
.font(.caption2)
.foregroundStyle(.orange)
Text(app.rating.formatted(.number.precision(.fractionLength(1))))
.font(.caption2.bold())
.foregroundStyle(.secondary)
Text("・" + app.category)
.font(.caption2)
.foregroundStyle(.secondary)
}
}
}
}
Spacer()
Button {
onToggleSave()
} label: {
Text(isSaved ? "保存済み" : "入手")
.font(.subheadline.bold())
.padding(.horizontal, 16)
.padding(.vertical, 6)
.background(isSaved ? Color(.secondarySystemBackground) : Color.blue.opacity(0.15))
.foregroundStyle(isSaved ? .secondary : .blue)
.clipShape(Capsule())
}
.buttonStyle(.plain)
}
}
}
// MARK: - 共通部品：アプリ詳細画面
struct AppDetailView: View {
let app: AppItem
let isSaved: Bool
let onToggleSave: () -> Void
@State private var showLaunchAlert = false
var body: some View {
ScrollView {
VStack(alignment: .leading, spacing: 20) {
HStack(spacing: 16) {
AppIconView(iconName: app.iconName, color: .white, backgroundColor: app.iconColor, size: 80)
VStack(alignment: .leading, spacing: 6) {
Text(app.name)
.font(.title2.bold())
Text(app.subtitle)
.font(.subheadline)
.foregroundStyle(.secondary)
HStack(spacing: 10) {
Button {
onToggleSave()
} label: {
Text(isSaved ? "保存済み" : "入手する")
.font(.subheadline.bold())
.padding(.horizontal, 20)
.padding(.vertical, 8)
.background(isSaved ? Color(.secondarySystemBackground) : Color.blue)
.foregroundStyle(isSaved ? .primary : .white)
.clipShape(Capsule())
}
Button {
showLaunchAlert = true
} label: {
Image(systemName: "square.and.arrow.up")
.font(.subheadline.bold())
.padding(8)
.background(Color(.secondarySystemBackground))
.clipShape(Circle())
}
}
.padding(.top, 4)
}
}
Divider()
HStack {
VStack {
Text("評価")
.font(.caption)
.foregroundStyle(.secondary)
Text("★ " + app.rating.formatted(.number.precision(.fractionLength(1))))
.font(.headline)
}
.frame(maxWidth: .infinity)
Divider()
VStack {
Text("ジャンル")
.font(.caption)
.foregroundStyle(.secondary)
Text(app.category)
.font(.headline)
}
.frame(maxWidth: .infinity)
}
.padding(.vertical, 8)
Divider()
VStack(alignment: .leading, spacing: 8) {
Text("このアプリについて")
.font(.headline)
Text(app.description)
.font(.body)
.foregroundStyle(.secondary)
}
}
.padding()
}
.navigationTitle(app.name)
.navigationBarTitleDisplayMode(.inline)
.alert("共有リンクをコピーしました", isPresented: $showLaunchAlert) {
Button("OK", role: .cancel) {}
}
}
}
// MARK: - 共通部品：アプリアイコン風デザイン
struct AppIconView: View {
let iconName: String
let color: Color
let backgroundColor: Color
let size: CGFloat
var body: some View {
Image(systemName: iconName)
.font(.system(size: size * 0.45))
.foregroundStyle(color)
.frame(width: size, height: size)
.background(backgroundColor)
.clipShape(RoundedRectangle(cornerRadius: size * 0.22))
}
}


