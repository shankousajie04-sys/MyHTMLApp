import SwiftUI

// MARK: - アプリのエントリポイント
@main
struct SimpleSwiftApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - データモデル
struct MemoItem: Identifiable {
    let id = UUID()
    let text: String
    let date: Date
}

// MARK: - メインビュー（タブ管理）
struct ContentView: View {
    @AppStorage("accentColorName") private var accentColorName: String = "Blue"

    var currentAccentColor: Color {
        switch accentColorName {
        case "Green": return .green
        case "Orange": return .orange
        case "Purple": return .purple
        default: return .blue
        }
    }

    var body: some View {
        TabView {
            CounterTabView()
                .tabItem {
                    Label("カウンター", systemImage: "plus.forwardslash.minus")
                }

            MemoTabView()
                .tabItem {
                    Label("クイックメモ", systemImage: "note.text")
                }

            TimerTabView()
                .tabItem {
                    Label("タイマー", systemImage: "timer")
                }

            SettingsTabView(accentColorName: $accentColorName)
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
        .accentColor(currentAccentColor)
    }
}

// MARK: - 1. カウンタータブ
struct CounterTabView: View {
    @AppStorage("savedCount") private var count: Int = 0
    @State private var step: Int = 1

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                Text("\(count)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))

                HStack(spacing: 24) {
                    Button {
                        withAnimation { count -= step }
                    } label: {
                        Image(systemName: "minus")
                            .font(.title2.bold())
                            .frame(width: 70, height: 70)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Circle())
                    }

                    Button {
                        withAnimation { count += step }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .frame(width: 70, height: 70)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }

                Stepper("増減幅: \(step)", value: $step, in: 1...100)
                    .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("カウンター")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        withAnimation { count = 0 }
                    } label: {
                        Text("リセット")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - 2. クイックメモタブ
struct MemoTabView: View {
    @State private var memos: [MemoItem] = []
    @State private var newMemoText: String = ""

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("新しいメモを入力...", text: $newMemoText)
                        .textFieldStyle(.roundedBorder)

                    Button("追加") {
                        addMemo()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newMemoText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()

                if memos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("メモがありません")
                            .font(.headline)
                        Text("上の入力欄からメモを追加できます")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(memos) { memo in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(memo.text)
                                    .font(.body)
                                Text(memo.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onDelete(perform: deleteMemo)
                    }
                }
            }
            .navigationTitle("クイックメモ")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !memos.isEmpty {
                        EditButton()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func addMemo() {
        let item = MemoItem(text: newMemoText, date: Date())
        withAnimation {
            memos.insert(item, at: 0)
            newMemoText = ""
        }
    }

    private func deleteMemo(at offsets: IndexSet) {
        memos.remove(atOffsets: offsets)
    }
}

// MARK: - 3. シンプルタイマータブ
struct TimerTabView: View {
    @State private var selectedSeconds: Double = 60
    @State private var remainingSeconds: Int = 60
    @State private var isRunning: Bool = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                Text(formatTime(remainingSeconds))
                    .font(.system(size: 64, weight: .semibold, design: .monospaced))

                if !isRunning {
                    VStack {
                        Text("時間設定: \(Int(selectedSeconds))秒")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Slider(value: $selectedSeconds, in: 10...600, step: 10) {
                            Text("秒数")
                        }
                        .onChange(of: selectedSeconds) { newValue in
                            remainingSeconds = Int(newValue)
                        }
                        .padding(.horizontal, 40)
                    }
                }

                HStack(spacing: 20) {
                    Button(isRunning ? "一時停止" : "スタート") {
                        isRunning.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("リセット") {
                        isRunning = false
                        remainingSeconds = Int(selectedSeconds)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Spacer()
            }
            .navigationTitle("タイマー")
            .onReceive(timer) { _ in
                guard isRunning else { return }
                if remainingSeconds > 0 {
                    remainingSeconds -= 1
                } else {
                    isRunning = false
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 4. 設定タブ
struct SettingsTabView: View {
    @Binding var accentColorName: String
    @State private var isNotificationsEnabled: Bool = true
    @State private var showAboutSheet: Bool = false

    let colors = ["Blue", "Green", "Orange", "Purple"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("外観")) {
                    Picker("テーマカラー", selection: $accentColorName) {
                        ForEach(colors, id: \.self) { color in
                            Text(color).tag(color)
                        }
                    }
                }

                Section(header: Text("一般")) {
                    Toggle("通知を受け取る（ダミー）", isOn: $isNotificationsEnabled)
                }

                Section(header: Text("情報")) {
                    Button("このアプリについて") {
                        showAboutSheet = true
                    }
                }
            }
            .navigationTitle("設定")
            .sheet(isPresented: $showAboutSheet) {
                VStack(spacing: 16) {
                    Image(systemName: "app.badge.checkmark")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)
                    Text("ただのSwiftアプリ")
                        .font(.title2.bold())
                    Text("SwiftUI標準コンポーネントのみで構築されたシンプルなユーティリティアプリです。")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    Button("閉じる") {
                        showAboutSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
