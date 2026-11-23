import SwiftUI
import UniformTypeIdentifiers
import Compression
import AVFoundation

@main
struct MyHTMLAppApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ExtractedFile: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let path: String
    let size: Int64
}

struct ContentView: View {
    private let appDisplayName = "ZIP解凍箱"

    @State private var files: [ExtractedFile] = []
    @State private var zipName = "未選択"
    @State private var showPicker = false
    @State private var showDeviceInfo = false

    @State private var previewFile: ExtractedFile?
    @State private var previewText = ""
    @State private var previewImage: UIImage?
    @State private var audioFile: ExtractedFile?

    @State private var shareItems: [Any] = []
    @State private var showShare = false
    @State private var message = ""
    @State private var showMessage = false

    private var rootDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ZIP解凍箱_展開済み", isDirectory: true)
    }

    private var inboxCopyDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ZIP解凍箱_取込一時", isDirectory: true)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZipFileBadgeView(size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appDisplayName).font(.headline)
                        Text("ZIP: \(zipName)").font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                    Spacer()
                    if !files.isEmpty {
                        Button("一括保存") {
                            shareItems = files.map(\.url)
                            showShare = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))

                if files.isEmpty {
                    VStack(spacing: 16) {
                        ZipFileBadgeView(size: 84)
                        Text(appDisplayName).font(.title2.bold())
                        Text("ZIPの中身を全部バラバラに展開します\n「ファイル」アプリから選ぶか、共有から送ってください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Button {
                            showPicker = true
                        } label: {
                            Label("ZIPファイルを選ぶ", systemImage: "folder.badge.plus")
                                .font(.headline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(files) { file in
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: file.url))
                                    .foregroundColor(iconColor(for: file.url))
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.name).font(.body.weight(.medium)).lineLimit(1)
                                    Text("\(formatSize(file.size))\(file.path != file.name ? " • \(file.path)" : "")")
                                        .font(.caption).foregroundColor(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Button {
                                    shareItems = [file.url]
                                    showShare = true
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                .buttonStyle(.borderless)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { open(file) }
                        }
                        .onDelete { offsets in
                            offsets.forEach { try? FileManager.default.removeItem(at: files[$0].url) }
                            reload()
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(appDisplayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            showDeviceInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        if !files.isEmpty {
                            Button("全消去", role: .destructive) {
                                try? FileManager.default.removeItem(at: rootDir)
                                files = []
                                zipName = "未選択"
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showPicker = true } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear(perform: reload)
        .onOpenURL { url in extract(url) }
        .sheet(isPresented: $showPicker) {
            ZipDocumentPicker { pickedURL in
                extract(pickedURL)
            }
        }
        .sheet(isPresented: $showDeviceInfo) {
            DeviceEnvInfoView(appName: appDisplayName)
        }
        .sheet(item: $previewFile) { file in
            NavigationView {
                Group {
                    if let img = previewImage {
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                    } else {
                        ScrollView {
                            Text(previewText)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }
                }
                .navigationTitle(file.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            shareItems = [file.url]
                            showShare = true
                        } label: { Image(systemName: "square.and.arrow.up") }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") { previewFile = nil; previewImage = nil }
                    }
                }
            }
        }
        .sheet(item: $audioFile, onDismiss: { audioFile = nil }) { file in
            AudioPlayerSheet(file: file) {
                shareItems = [file.url]
                showShare = true
            }
        }
        .sheet(isPresented: $showShare) {
            ShareView(items: shareItems)
        }
        .alert(appDisplayName, isPresented: $showMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message)
        }
    }

    private func extract(_ sourceURL: URL) {
        let ok = sourceURL.startAccessingSecurityScopedResource()
        defer { if ok { sourceURL.stopAccessingSecurityScopedResource() } }

        do {
            let fm = FileManager.default
            if fm.fileExists(atPath: inboxCopyDir.path) {
                try fm.removeItem(at: inboxCopyDir)
            }
            try fm.createDirectory(at: inboxCopyDir, withIntermediateDirectories: true)

            let fileName = sourceURL.lastPathComponent.isEmpty ? "archive.zip" : sourceURL.lastPathComponent
            let copiedURL = inboxCopyDir.appendingPathComponent(fileName)
            if fm.fileExists(atPath: copiedURL.path) {
                try fm.removeItem(at: copiedURL)
            }

            if coordinatedCopy(from: sourceURL, to: copiedURL, fm: fm) == nil {
                try fm.copyItem(at: sourceURL, to: copiedURL)
            }

            let data = try Data(contentsOf: copiedURL)
            if fm.fileExists(atPath: rootDir.path) { try fm.removeItem(at: rootDir) }
            try fm.createDirectory(at: rootDir, withIntermediateDirectories: true)

            let count = try ZipUnpacker.unpack(data: data, to: rootDir)
            zipName = fileName
            reload()
            message = "「\(zipName)」から \(count) 個のファイルを取り出しました。"
            showMessage = true
        } catch {
            message = "解凍失敗: \(error.localizedDescription)"
            showMessage = true
        }
    }

    private func coordinatedCopy(from src: URL, to dst: URL, fm: FileManager) -> Bool? {
        var error: NSError?
        var ok = false
        NSFileCoordinator().coordinate(readingItemAt: src, options: [], error: &error) { url in
            if (try? fm.copyItem(at: url, to: dst)) != nil {
                ok = true
            }
        }
        return error == nil && ok ? true : nil
    }

    private func reload() {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: rootDir, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles]) else {
            files = []; return
        }
        var list: [ExtractedFile] = []
        let base = rootDir.standardizedFileURL.path
        for case let u as URL in enumerator {
            let v = try? u.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if v?.isDirectory == true || u.path.contains("__MACOSX") { continue }
            let rel = u.standardizedFileURL.path.replacingOccurrences(of: base + "/", with: "")
            list.append(ExtractedFile(id: u.path, url: u, name: u.lastPathComponent, path: rel, size: Int64(v?.fileSize ?? 0)))
        }
        files = list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func isAudio(_ url: URL) -> Bool {
        ["mp3", "wav", "m4a", "aac", "caf", "aiff"].contains(url.pathExtension.lowercased())
    }

    private func isText(_ url: URL) -> Bool {
        ["txt", "json", "xml", "html", "htm", "css", "js", "ts", "swift", "py", "md", "csv", "log", "yml", "yaml"].contains(url.pathExtension.lowercased())
    }

    private func open(_ file: ExtractedFile) {
        if isAudio(file.url) {
            audioFile = file
            return
        }
        if let data = try? Data(contentsOf: file.url), let img = UIImage(data: data) {
            previewImage = img
            previewText = ""
            previewFile = file
            return
        }
        if isText(file.url),
           let data = try? Data(contentsOf: file.url),
           let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS) {
            previewImage = nil
            previewText = str
            previewFile = file
            return
        }
        message = "現在その拡張子やファイルはZIP BOXには対応していません。"
        showMessage = true
    }

    private func icon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return "photo.fill"
        case "mp3", "wav", "m4a", "aac", "caf", "aiff": return "waveform"
        case "mp4", "mov": return "film.fill"
        case "pdf": return "doc.richtext.fill"
        case "zip": return "doc.zipper"
        default: return "doc.text.fill"
        }
    }

    private func iconColor(for url: URL) -> Color {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return .pink
        case "mp3", "wav", "m4a", "aac", "caf", "aiff": return .purple
        case "zip": return .orange
        default: return .blue
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

struct ZipFileBadgeView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )
            Image(systemName: "doc.zipper")
                .font(.system(size: size * 0.52, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(0.08), radius: size * 0.06, x: 0, y: size * 0.03)
    }
}

struct DeviceEnvInfoView: View {
    let appName: String
    @Environment(\.presentationMode) private var presentationMode

    private var device: UIDevice { UIDevice.current }
    private var bundleID: String { Bundle.main.bundleIdentifier ?? "-" }
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("自分の端末・iOS環境")) {
                    LabeledContentRow(label: "OS", value: "\(device.systemName) \(device.systemVersion)")
                    LabeledContentRow(label: "端末種別", value: device.localizedModel)
                    LabeledContentRow(label: "モデル名", value: device.model)
                }
                Section(header: Text("インストール環境・アプリ情報")) {
                    LabeledContentRow(label: "表示名", value: appName)
                    LabeledContentRow(label: "Bundle ID", value: bundleID)
                    LabeledContentRow(label: "バージョン", value: appVersion)
                    LabeledContentRow(label: "導入経路", value: "GitHub Actions / KSign 署名導入")
                }
            }
            .navigationTitle("環境・バージョン情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

private struct LabeledContentRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

struct AudioPlayerSheet: View {
    let file: ExtractedFile
    let onShare: () -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 1
    @State private var errorText: String?
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.purple)

                Text(file.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let err = errorText {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    VStack(spacing: 6) {
                        Slider(
                            value: Binding(
                                get: { currentTime },
                                set: { newVal in
                                    currentTime = newVal
                                    player?.currentTime = newVal
                                }
                            ),
                            in: 0...max(duration, 0.1)
                        )
                        HStack {
                            Text(timeText(currentTime))
                            Spacer()
                            Text(timeText(duration))
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }

                Button {
                    togglePlay()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.purple)
                }
                .disabled(errorText != nil)
            }
            .padding()
            .navigationTitle("音声再生")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") {
                        player?.stop()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear(perform: setupPlayer)
        .onDisappear { player?.stop() }
        .onReceive(timer) { _ in
            guard let p = player else { return }
            currentTime = p.currentTime
            isPlaying = p.isPlaying
        }
    }

    private func setupPlayer() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: file.url)
            p.prepareToPlay()
            duration = max(p.duration, 0.1)
            player = p
            p.play()
            isPlaying = true
        } catch {
            errorText = "この音声ファイルを再生できませんでした: \(error.localizedDescription)"
        }
    }

    private func togglePlay() {
        guard let p = player else { return }
        if p.isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }
    }

    private func timeText(_ sec: TimeInterval) -> String {
        let total = Int(max(0, sec))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct ZipDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [
            .zip,
            UTType(filenameExtension: "zip") ?? .data,
            .archive,
            .data,
            .item
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let first = urls.first {
                onPick(first)
            }
        }
    }
}

struct ShareView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum ZipUnpacker {
    static func unpack(data: Data, to dir: URL) throws -> Int {
        let fm = FileManager.default
        var count = 0

        if let entries = readCentralDirectory(data), !entries.isEmpty {
            for e in entries where !e.name.hasSuffix("/") && !e.name.contains("__MACOSX") {
                let off = Int(e.localOffset)
                guard off + 30 <= data.count, data.u32(off) == 0x04034b50 else { continue }
                let start = off + 30 + Int(data.u16(off + 26)) + Int(data.u16(off + 28))
                let end = start + Int(e.compSize)
                guard start >= 0, end <= data.count, start <= end else { continue }
                let raw = try decode(Data(data.subdata(in: start..<end)), method: e.method, uncompSize: Int(e.uncompSize))
                let clean = sanitizePath(e.name)
                guard !clean.isEmpty else { continue }
                let out = dir.appendingPathComponent(clean)
                try fm.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
                try raw.write(to: out, options: .atomic)
                count += 1
            }
            if count > 0 { return count }
        }

        var off = 0
        while off + 30 <= data.count, data.u32(off) == 0x04034b50 {
            let method = data.u16(off + 8)
            let comp = Int(data.u32(off + 18))
            let uncomp = Int(data.u32(off + 22))
            let nLen = Int(data.u16(off + 26))
            let eLen = Int(data.u16(off + 28))
            let nStart = off + 30
            let pStart = nStart + nLen + eLen
            let pEnd = pStart + comp
            guard pEnd <= data.count, pStart <= pEnd else { break }
            let nameData = Data(data.subdata(in: nStart..<(nStart + nLen)))
            let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .shiftJIS) ?? "file_\(count)"
            if !name.hasSuffix("/") && !name.contains("__MACOSX") {
                let raw = try decode(Data(data.subdata(in: pStart..<pEnd)), method: method, uncompSize: uncomp)
                let clean = sanitizePath(name)
                if !clean.isEmpty {
                    let out = dir.appendingPathComponent(clean)
                    try fm.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try raw.write(to: out, options: .atomic)
                    count += 1
                }
            }
            off = pEnd
        }
        guard count > 0 else {
            throw NSError(domain: "ZIP解凍箱", code: 1, userInfo: [NSLocalizedDescriptionKey: "解凍できるファイルがありません"])
        }
        return count
    }

    private static func sanitizePath(_ rawPath: String) -> String {
        rawPath
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .filter { $0 != "." && $0 != ".." && !$0.isEmpty }
            .joined(separator: "/")
    }

    private struct Entry {
        let method: UInt16
        let compSize: UInt32
        let uncompSize: UInt32
        let localOffset: UInt32
        let name: String
    }

    private static func readCentralDirectory(_ data: Data) -> [Entry]? {
        guard data.count >= 22 else { return nil }
        let searchStart = max(0, data.count - 65557)
        let searchEnd = data.count - 22
        guard searchStart <= searchEnd,
              let eocd = (searchStart...searchEnd).reversed().first(where: { data.u32($0) == 0x06054b50 }) else {
            return nil
        }
        let total = Int(data.u16(eocd + 10))
        var cur = Int(data.u32(eocd + 16))
        var res: [Entry] = []
        for _ in 0..<total {
            guard cur + 46 <= data.count, data.u32(cur) == 0x02014b50 else { break }
            let nLen = Int(data.u16(cur + 28))
            let eLen = Int(data.u16(cur + 30))
            let cLen = Int(data.u16(cur + 32))
            guard cur + 46 + nLen <= data.count else { break }
            let nameData = Data(data.subdata(in: (cur + 46)..<(cur + 46 + nLen)))
            let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .shiftJIS) ?? "item"
            res.append(Entry(
                method: data.u16(cur + 10),
                compSize: data.u32(cur + 20),
                uncompSize: data.u32(cur + 24),
                localOffset: data.u32(cur + 42),
                name: name
            ))
            cur += 46 + nLen + eLen + cLen
        }
        return res
    }

    private static func decode(_ src: Data, method: UInt16, uncompSize: Int) throws -> Data {
        if method == 0 { return src }
        if method == 8 {
            if src.isEmpty { return Data() }
            if let streamDecoded = decompressStream(src: src, initialHint: uncompSize) {
                return streamDecoded
            }
            var wrapped = Data([0x78, 0x9C])
            wrapped.append(src)
            wrapped.append(contentsOf: [0x00, 0x00, 0x00, 0x00])
            if let wrappedDecoded = decompressStream(src: wrapped, initialHint: uncompSize) {
                return wrappedDecoded
            }
            throw NSError(domain: "ZIP解凍箱", code: 2, userInfo: [NSLocalizedDescriptionKey: "解凍エラー"])
        }
        throw NSError(domain: "ZIP解凍箱", code: 3, userInfo: [NSLocalizedDescriptionKey: "未対応形式(\(method))"])
    }

    private static func decompressStream(src: Data, initialHint: Int) -> Data? {
        var stream = compression_stream(
            dst_ptr: UnsafeMutablePointer<UInt8>.allocate(capacity: 1),
            dst_size: 0,
            src_ptr: UnsafePointer<UInt8>(bitPattern: 1)!,
            src_size: 0,
            state: nil
        )
        stream.dst_ptr.deallocate()

        let status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
        guard status == COMPRESSION_STATUS_OK else { return nil }
        defer { compression_stream_destroy(&stream) }

        let chunkSize = max(initialHint > 0 ? min(initialHint, 1024 * 1024) : 65536, 16384)
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { dstBuffer.deallocate() }

        var output = Data(capacity: max(initialHint, 1024))

        return src.withUnsafeBytes { rawBuf -> Data? in
            guard let base = rawBuf.bindMemory(to: UInt8.self).baseAddress else { return nil }
            stream.src_ptr = base
            stream.src_size = src.count

            while true {
                stream.dst_ptr = dstBuffer
                stream.dst_size = chunkSize
                let flags: Int32 = (stream.src_size == 0) ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0
                let res = compression_stream_process(&stream, flags)
                let produced = chunkSize - stream.dst_size
                if produced > 0 {
                    output.append(dstBuffer, count: produced)
                }

                switch res {
                case COMPRESSION_STATUS_END:
                    return output
                case COMPRESSION_STATUS_OK:
                    continue
                default:
                    return nil
                }
            }
        }
    }
}

private extension Data {
    func u16(_ o: Int) -> UInt16 {
        let i = startIndex + o
        return UInt16(self[i]) | (UInt16(self[i + 1]) << 8)
    }

    func u32(_ o: Int) -> UInt32 {
        let i = startIndex + o
        return UInt32(self[i])
            | (UInt32(self[i + 1]) << 8)
            | (UInt32(self[i + 2]) << 16)
            | (UInt32(self[i + 3]) << 24)
    }
}
