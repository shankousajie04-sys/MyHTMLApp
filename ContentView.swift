import SwiftUI
import WebKit

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
        WebView()
            .ignoresSafeArea()
    }
}

struct WebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.loadHTMLString("""
        <!DOCTYPE html>
        <html lang="ja">
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body {
            background: #111;
            color: white;
            font-family: sans-serif;
            text-align: center;
            padding: 30px;
        }
        </style>
        </head>
        <body>
        <h1>My HTML App</h1>
        <p>アプリ起動成功！</p>
        </body>
        </html>
        """, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
