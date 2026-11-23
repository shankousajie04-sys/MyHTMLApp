import SwiftUI
import UniformTypeIdentifiers
import Compression

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
    @State private var files: [ExtractedFile] = []
    @State private var zipName = "未選択"
    @State private var showPicker = false
    @State private var previewFile: ExtractedFile?
    @State private var previewText = ""
    @State private var previewImage: UIImage?
    @State private var shareItems: [Any] = []
    @State private var showShare = false
    @State private var message = ""
    @State private var showMessage = false

    private var rootDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Extracted", isDirectory: true)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ZIP: \(zipName)").font(.subheadline.bold()).lineLimit(1)
                        Text("ファイルアプリでZIPを選択 → 共有からこのアプリを選択").font(.caption2).foregroundColor(.secondary)
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
                    VStack(spacing: 14) {
                        Image(systemName: "doc.zipper").font(.system(size: 50)).foregroundColor(.orange)
                        Text("ZIPの中身を全部バラバラに展開").font(.headline)
                        Text("1. 「ファイル」アプリでZIPを選択\n2. 「共有」からこのアプリを選ぶ\n3. 中身のファイルが全部表示されます")
                            .font(.caption).foregroundColor(.secondary)
                            .padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
                        Button("ZIPファイルを選ぶ") { showPicker = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(files) { file in
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: file.url))
                                    .foregroundColor(.blue).frame(width: 28)
                                VStack(alignment: .leading) {
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
            .navigationTitle("iZip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !files.isEmpty {
                        Button("全消去", role: .destructive) {
                            try? FileManager.default.removeItem(at: rootDir)
                            files = []
                            zipName = "未選択"
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
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.zip, UTType(filenameExtension: "zip") ?? .data]
        ) { result in
            if case .success(let url) = result {
                extract(url)
            }
        }
        .sheet(item: $previewFile) { file in
            NavigationView {
                Group {
                    if let img = previewImage {
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: img).resizable().scaledToFit().padding()
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
        .sheet(isPresented: $showShare) {
            ShareView(items: shareItems)
        }
        .alert("iZip", isPresented: $showMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message)
        }
    }

    private func extract(_ url: URL) {
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let fm = FileManager.default
            if fm.fileExists(atPath: rootDir.path) { try fm.removeItem(at: rootDir) }
            try fm.createDirectory(at: rootDir, withIntermediateDirectories: true)
            let count = try ZipUnpacker.unpack(data: data, to: rootDir)
            zipName = url.lastPathComponent
            reload()
            message = "「\(zipName)」から \(count) 個のファイルを取り出しました。"
            showMessage = true
        } catch {
            message = "解凍失敗: \(error.localizedDescription)"
            showMessage = true
        }
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

    private func open(_ file: ExtractedFile) {
        if let data = try? Data(contentsOf: file.url) {
            if let img = UIImage(data: data) {
                previewImage = img; previewText = ""; previewFile = file; return
            }
            if let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS) {
                previewImage = nil; previewText = str; previewFile = file; return
            }
        }
        shareItems = [file.url]
        showShare = true
    }

    private func icon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return "photo.fill"
        case "mp3", "wav", "m4a": return "waveform"
        case "mp4", "mov": return "film.fill"
        case "pdf": return "doc.richtext.fill"
        default: return "doc.text.fill"
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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
                guard end <= data.count else { continue }
                let raw = try decode(data.subdata(in: start..<end), method: e.method, uncompSize: Int(e.uncompSize))
                let clean = e.name.split(separator: "/").filter { $0 != "." && $0 != ".." }.joined(separator: "/")
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
            guard pEnd <= data.count else { break }
            let name = String(data: data.subdata(in: nStart..<(nStart + nLen)), encoding: .utf8) ?? "file_\(count)"
            if !name.hasSuffix("/") && !name.contains("__MACOSX") {
                let raw = try decode(data.subdata(in: pStart..<pEnd), method: method, uncompSize: uncomp)
                let clean = name.split(separator: "/").filter { $0 != "." && $0 != ".." }.joined(separator: "/")
                if !clean.isEmpty {
                    let out = dir.appendingPathComponent(clean)
                    try fm.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try raw.write(to: out, options: .atomic)
                    count += 1
                }
            }
            off = pEnd
        }
        guard count > 0 else { throw NSError(domain: "iZip", code: 1, userInfo: [NSLocalizedDescriptionKey: "解凍できるファイルがありません"]) }
        return count
    }

    private struct Entry { let method: UInt16; let compSize: UInt32; let uncompSize: UInt32; let localOffset: UInt32; let name: String }

    private static func readCentralDirectory(_ data: Data) -> [Entry]? {
        guard data.count >= 22 else { return nil }
        guard let eocd = (max(0, data.count - 65557)...(data.count - 22)).reversed().first(where: { data.u32($0) == 0x06054b50 }) else { return nil }
        let total = Int(data.u16(eocd + 10))
        var cur = Int(data.u32(eocd + 16))
        var res: [Entry] = []
        for _ in 0..<total {
            guard cur + 46 <= data.count, data.u32(cur) == 0x02014b50 else { break }
            let nLen = Int(data.u16(cur + 28)), eLen = Int(data.u16(cur + 30)), cLen = Int(data.u16(cur + 32))
            guard cur + 46 + nLen <= data.count else { break }
            let nameData = data.subdata(in: (cur + 46)..<(cur + 46 + nLen))
            let name = String(data: nameData, encoding: .utf8) ?? String(data: nameData, encoding: .shiftJIS) ?? "item"
            res.append(Entry(method: data.u16(cur + 10), compSize: data.u32(cur + 20), uncompSize: data.u32(cur + 24), localOffset: data.u32(cur + 42), name: name))
            cur += 46 + nLen + eLen + cLen
        }
        return res
    }

    private static func decode(_ src: Data, method: UInt16, uncompSize: Int) throws -> Data {
        if method == 0 { return src }
        if method == 8 {
            if uncompSize == 0 { return Data() }
            let cap = max(uncompSize, 64)
            var dst = [UInt8](repeating: 0, count: cap)
            let outSize = src.withUnsafeBytes { ptr -> Int in
                guard let base = ptr.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(&dst, cap, base, src.count, nil, COMPRESSION_ZLIB)
            }
            guard outSize > 0 else { throw NSError(domain: "iZip", code: 2, userInfo: [NSLocalizedDescriptionKey: "解凍エラー"]) }
            return Data(dst.prefix(outSize))
        }
        throw NSError(domain: "iZip", code: 3, userInfo: [NSLocalizedDescriptionKey: "未対応形式(\(method))"])
    }
}

private extension Data {
    func u16(_ o: Int) -> UInt16 { UInt16(self[o]) | (UInt16(self[o + 1]) << 8) }
    func u32(_ o: Int) -> UInt32 { UInt32(self[o]) | (UInt32(self[o + 1]) << 8) | (UInt32(self[o + 2]) << 16) | (UInt32(self[o + 3]) << 24) }
}
