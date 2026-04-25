import SwiftUI
import WebKit

struct TermsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.blue)
                    }

                    Spacer()

                    Text("Terms of Service")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    // Placeholder for alignment
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.clear)
                    .hidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemBackground))
                .border(Color(UIColor.separator), width: 0.5)

                // Terms Content WebView
                TermsWebView()
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

struct TermsWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)

        // Configure web view preferences
        webView.configuration.preferences.javaScriptEnabled = false
        webView.configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        // Load Terms of Service HTML
        if let htmlPath = Bundle.main.url(forResource: "terms", withExtension: "html"),
           let htmlString = try? String(contentsOf: htmlPath, encoding: .utf8) {
            webView.loadHTMLString(htmlString, baseURL: htmlPath.deletingLastPathComponent())
        } else {
            // Fallback: Load from remote URL if local file not available
            if let url = URL(string: "https://grooveai.app/terms") {
                webView.load(URLRequest(url: url))
            } else {
                // Display error message if neither option works
                let errorHTML = """
                <html>
                <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; padding: 20px; color: #333;">
                <h2>Unable to Load Terms</h2>
                <p>We're sorry, but we couldn't load the Terms of Service at this time.</p>
                <p>Please try again later or contact support@grooveai.app for assistance.</p>
                </body>
                </html>
                """
                webView.loadHTMLString(errorHTML, baseURL: nil)
            }
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

#Preview {
    NavigationStack {
        TermsView()
    }
}
