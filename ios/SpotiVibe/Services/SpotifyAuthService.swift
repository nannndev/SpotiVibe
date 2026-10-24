import Foundation
import CryptoKit
import AuthenticationServices

@MainActor
public class SpotifyAuthService: NSObject, ObservableObject {
    public static let shared = SpotifyAuthService()

    @Published public var isAuthenticated: Bool = false
    @Published public var accessToken: String? = nil
    @Published public var isAuthenticating: Bool = false
    @Published public var errorMessage: String? = nil

    public static let defaultClientID = "9e2d96c8642b4f4fa2274d95cc5ef0da"
    public static let defaultRedirectURI = "opennotchi://spotify-callback"

    @Published public var clientID: String {
        didSet {
            UserDefaults.standard.set(clientID, forKey: clientIDKey)
        }
    }

    @Published public var redirectURI: String {
        didSet {
            UserDefaults.standard.set(redirectURI, forKey: redirectURIKey)
        }
    }

    private var codeVerifier: String?

    private let clientIDKey = "spotivibe.spotify.client_id"
    private let redirectURIKey = "spotivibe.spotify.redirect_uri"
    private let tokenKey = "spotivibe.spotify.access_token"
    private let refreshTokenKey = "spotivibe.spotify.refresh_token"
    private let tokenExpiryKey = "spotivibe.spotify.token_expiry"

    override private init() {
        let storedClientID = UserDefaults.standard.string(forKey: clientIDKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored = storedClientID, !stored.isEmpty, !stored.contains("your_spotify") {
            self.clientID = stored
        } else {
            self.clientID = Self.defaultClientID
            UserDefaults.standard.set(Self.defaultClientID, forKey: clientIDKey)
        }

        let storedRedirect = UserDefaults.standard.string(forKey: redirectURIKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored = storedRedirect, !stored.isEmpty {
            self.redirectURI = stored
        } else {
            self.redirectURI = Self.defaultRedirectURI
            UserDefaults.standard.set(Self.defaultRedirectURI, forKey: redirectURIKey)
        }

        super.init()
        loadStoredToken()
    }

    private func loadStoredToken() {
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            let expiry = UserDefaults.standard.double(forKey: tokenExpiryKey)
            if Date().timeIntervalSince1970 < expiry {
                self.accessToken = token
                self.isAuthenticated = true
            } else if UserDefaults.standard.string(forKey: refreshTokenKey) != nil {
                Task { await refreshAccessToken() }
            }
        }
    }

    public func authorize(from window: ASPresentationAnchor) {
        let cleanID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanID.isEmpty else {
            errorMessage = "Please enter a valid Spotify Client ID"
            return
        }

        errorMessage = nil
        let verifier = generateCodeVerifier()
        self.codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: cleanID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: "user-read-currently-playing user-read-playback-state user-modify-playback-state")
        ]

        guard let authURL = components.url else { return }

        // Extract callback scheme (e.g. "opennotchi" or "spotivibe")
        let scheme = URL(string: redirectURI)?.scheme ?? "opennotchi"

        isAuthenticating = true
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: scheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            Task { @MainActor in
                self.isAuthenticating = false
                if let error = error {
                    // Ignore user cancellation error
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain && nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        return
                    }
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let callbackURL = callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    return
                }
                await self.exchangeCodeForToken(code: code)
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    private func exchangeCodeForToken(code: String) async {
        guard let verifier = codeVerifier else { return }
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let cleanID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let params: [String: String] = [
            "client_id": cleanID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": verifier
        ]

        request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errorDesc = json["error_description"] as? String {
                    self.errorMessage = errorDesc
                    return
                }
                if let token = json["access_token"] as? String,
                   let expiresIn = json["expires_in"] as? Double {
                    self.accessToken = token
                    self.isAuthenticated = true
                    UserDefaults.standard.set(token, forKey: tokenKey)
                    UserDefaults.standard.set(Date().timeIntervalSince1970 + expiresIn, forKey: tokenExpiryKey)
                    if let refreshToken = json["refresh_token"] as? String {
                        UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
                    }
                    SpotifyPlayerService.shared.poll()
                }
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func refreshAccessToken() async {
        guard let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey),
              let url = URL(string: "https://accounts.spotify.com/api/token") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let cleanID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let params: [String: String] = [
            "client_id": cleanID,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]

        request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        if let (data, _) = try? await URLSession.shared.data(for: request),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["access_token"] as? String,
           let expiresIn = json["expires_in"] as? Double {
            self.accessToken = token
            self.isAuthenticated = true
            UserDefaults.standard.set(token, forKey: tokenKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970 + expiresIn, forKey: tokenExpiryKey)
        }
    }

    public func resetToDefaults() {
        clientID = Self.defaultClientID
        redirectURI = Self.defaultRedirectURI
        logout()
    }

    public func logout() {
        accessToken = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
    }

    // PKCE Helpers
    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
}

extension SpotifyAuthService: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            return window
        }
        return ASPresentationAnchor()
    }
}
