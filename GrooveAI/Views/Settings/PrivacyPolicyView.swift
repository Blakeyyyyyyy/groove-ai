import SwiftUI
import WebKit

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }

                    Spacer()

                    Text("Privacy Policy")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    // Spacer for alignment
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                    }
                    .foregroundColor(.clear)
                }
                .frame(height: 44)
                .padding(.horizontal, 16)
                .borderBottom()

                // Content
                if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)

                        Text("Unable to Load Privacy Policy")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(error)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: { retry() }) {
                            Text("Try Again")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                    .multilineTextAlignment(.center)
                } else {
                    WebViewContainer(
                        url: privacyPolicyURL(),
                        isLoading: $isLoading,
                        loadError: $loadError
                    )
                }

                // Loading indicator overlay
                if isLoading && loadError == nil {
                    VStack {
                        HStack {
                            ProgressView()
                                .tint(.blue)
                            Text("Loading Privacy Policy...")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray3), lineWidth: 1)
                        )
                        .padding(16)

                        Spacer()
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func privacyPolicyURL() -> URL {
        // Try loading from local file first (embedded in app bundle)
        if let localURL = Bundle.main.url(forResource: "privacy", withExtension: "html") {
            return localURL
        }

        // Fallback to remote URL
        return URL(string: "https://grooveai.app/privacy") ?? URL(fileURLWithPath: "")
    }

    private func retry() {
        loadError = nil
        isLoading = true
    }
}

// MARK: - WebView Container

struct WebViewContainer: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        // Disable most scripts and plugins for security
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        configuration.preferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        // Load with timeout
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        request.setValue("Groove-AI/1.0", forHTTPHeaderField: "User-Agent")

        webView.load(request)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, loadError: $loadError)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var loadError: String?

        init(isLoading: Binding<Bool>, loadError: Binding<String?>) {
            self._isLoading = isLoading
            self._loadError = loadError
        }

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            isLoading = true
            loadError = nil
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            isLoading = false
            loadError = nil
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            handleError(error)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            handleError(error)
        }

        private func handleError(_ error: Error) {
            isLoading = false

            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    loadError = "The request took too long. Please check your internet connection and try again."
                case .notConnectedToInternet, .networkConnectionLost:
                    loadError = "No internet connection. Please check your connection and try again."
                case .serverCertificateUntrusted:
                    loadError = "Unable to verify the server's security certificate."
                default:
                    loadError = "Failed to load the privacy policy. Please try again later."
                }
            } else {
                loadError = error.localizedDescription.isEmpty
                    ? "An unexpected error occurred. Please try again."
                    : error.localizedDescription
            }
        }
    }
}

// MARK: - Helper Extensions

extension View {
    func borderBottom(color: Color = Color(.systemGray3), width: CGFloat = 1) -> some View {
        VStack(spacing: 0) {
            self
            Divider()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
