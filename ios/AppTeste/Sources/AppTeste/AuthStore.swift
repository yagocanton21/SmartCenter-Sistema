import Foundation
import Combine

struct LoginUser: Decodable {
    let id: String
    let nome: String
    let login: String
    let perfil: String
    let perms: [String]?

    func can(_ permission: String) -> Bool { perfil == "admin" || (perms ?? []).contains(permission) }
}

private struct LoginSession: Decodable {
    let user: LoginUser
    let csrf: String
}

private struct APIError: Decodable { let error: String }

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var user: LoginUser?
    @Published private(set) var busy = false
    @Published private(set) var restoring = true
    private var restored = false
    @Published var error: String?
    @Published private(set) var dashboard: DashboardData?
    @Published private(set) var loadingDashboard = false
    @Published private(set) var dashboardError: String?
    @Published private(set) var updatedAt: Date?
    private var csrf = ""
    private var baseURL: URL?
    // Optional persistent cookie lives in Keychain, never in UserDefaults.
    private let session = URLSession(configuration: .ephemeral)

    private func request(_ path: String, base: URL, body: [String: String]? = nil, token: String? = nil) async throws -> Data {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = body == nil ? "GET" : "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue(token, forHTTPHeaderField: "X-CSRF-Token") }
        if let body { request.httpBody = try JSONEncoder().encode(body) }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(APIError.self, from: data).error)
                ?? "O servidor retornou erro \(response.statusCode)."
            throw NSError(domain: "Smartcenter", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return data
    }

    func login(server: String, username: String, password: String, remember: Bool) async {
        guard !busy else { return }
        error = nil
        guard let url = URL(string: server.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/" else {
            error = "Informe o endereço do servidor, incluindo http:// ou https://."
            return
        }
        busy = true
        defer { busy = false }
        do {
            try SessionVault.clear()
            let data = try await request("api/auth/login", base: url, body: ["login": username.trimmingCharacters(in: .whitespacesAndNewlines), "password": password])
            let result = try JSONDecoder().decode(LoginSession.self, from: data)
            baseURL = url
            csrf = result.csrf
            user = result.user
            dashboard = nil
            dashboardError = nil
            updatedAt = nil
            if remember {
                do {
                    guard let cookie = session.configuration.httpCookieStorage?.cookies(for: url)?.first(where: { $0.name == "sc_session" }), let expires = cookie.expiresDate else {
                        throw URLError(.cannotParseResponse)
                    }
                    try SessionVault.save(SavedSession(server: url.absoluteString, token: cookie.value, expires: expires, secure: cookie.isSecure))
                } catch { self.error = "Login realizado, mas não foi possível manter a sessão salva neste iPhone." }
            }
        } catch { self.error = message(for: error) }
    }

    func restoreSession(server: String, enabled: Bool) async {
        guard !restored else { return }
        restored = true
        defer { restoring = false }
        do {
            guard enabled else { try SessionVault.clear(); return }
            guard let saved = try SessionVault.load() else { return }
            guard saved.expires > Date(), saved.server == server.trimmingCharacters(in: .whitespacesAndNewlines),
                  let url = URL(string: saved.server), let host = url.host,
                  ["http", "https"].contains(url.scheme ?? "") else { try SessionVault.clear(); return }
            var properties: [HTTPCookiePropertyKey: Any] = [.name: "sc_session", .value: saved.token, .domain: host, .path: "/", .expires: saved.expires]
            if saved.secure { properties[.secure] = "TRUE" }
            guard let cookie = HTTPCookie(properties: properties) else { try SessionVault.clear(); return }
            session.configuration.httpCookieStorage?.setCookie(cookie)
            let data = try await request("api/auth/session", base: url)
            let result = try JSONDecoder().decode(LoginSession.self, from: data)
            baseURL = url; csrf = result.csrf; user = result.user
        } catch {
            if (error as NSError).domain == "Smartcenter", (error as NSError).code == 401 {
                try? SessionVault.clear()
                self.error = "Sua sessão expirou. Entre novamente."
            } else { self.error = message(for: error) }
            session.configuration.httpCookieStorage?.cookies?.forEach { session.configuration.httpCookieStorage?.deleteCookie($0) }
        }
    }

    func logout() async {
        guard !busy, let baseURL else { return }
        busy = true
        error = nil
        defer { busy = false }
        do {
            try SessionVault.clear()
            _ = try await request("api/auth/logout", base: baseURL, body: [:], token: csrf)
            user = nil
            csrf = ""
            self.baseURL = nil
            dashboard = nil
            updatedAt = nil
            session.configuration.httpCookieStorage?.cookies?.forEach {
                session.configuration.httpCookieStorage?.deleteCookie($0)
            }
        } catch {
            if (error as NSError).domain == "Smartcenter", (error as NSError).code == 401 {
                user = nil
                try? SessionVault.clear()
                csrf = ""
                self.baseURL = nil
                dashboard = nil
                updatedAt = nil
            } else { self.error = message(for: error) }
        }
    }

    func loadDashboard() async {
        guard !loadingDashboard, let baseURL, let currentUser = user else { return }
        loadingDashboard = true
        dashboardError = nil
        defer { loadingDashboard = false }
        do {
            let data = try await request("api/db", base: baseURL)
            let snapshot = try JSONDecoder().decode(DashboardSnapshot.self, from: data)
            guard user?.id == currentUser.id else { return }
            dashboard = snapshot.db
            updatedAt = Date()
        } catch {
            guard user?.id == currentUser.id else { return }
            if (error as NSError).domain == "Smartcenter", (error as NSError).code == 401 {
                user = nil
                try? SessionVault.clear()
                csrf = ""
                self.baseURL = nil
                dashboard = nil
                updatedAt = nil
                self.error = "Sua sessão expirou. Entre novamente."
            } else { dashboardError = message(for: error) }
        }
    }

    func recordPage(entity: String, page: Int, query: String, status: String) async throws -> MobileRecordPage {
        guard let baseURL, user != nil else { throw URLError(.userAuthenticationRequired) }
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "pageSize", value: "10"), URLQueryItem(name: "q", value: query)]
        if status != "Todos" { components.queryItems?.append(URLQueryItem(name: "status", value: status)) }
        // URLRequest's path helper cannot contain a query string.
        let url = baseURL.appendingPathComponent("api/mobile/records/" + entity)
        var target = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        target.queryItems = components.queryItems
        var request = URLRequest(url: target.url!)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        if statusCode == 401 {
            try? SessionVault.clear()
            user = nil; csrf = ""; self.baseURL = nil; dashboard = nil; updatedAt = nil
            error = "Sua sessão expirou. Entre novamente."
        }
        guard (200..<300).contains(statusCode) else {
            let message = statusCode == 404 ? "A API precisa ser atualizada para oferecer paginação." : (try? JSONDecoder().decode(APIError.self, from: data).error) ?? "Falha ao carregar registros (\(statusCode))."
            throw NSError(domain: "Smartcenter", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return try JSONDecoder().decode(MobileRecordPage.self, from: data)
    }

    func orderRequest(_ path: String, body: Data? = nil, idempotencyKey: String? = nil, permission: String = "os") async throws -> Data {
        guard let baseURL, user?.can(permission) == true else { throw URLError(.userAuthenticationRequired) }
        let fullURL: URL
        if let direct = URL(string: path, relativeTo: baseURL) {
            fullURL = direct.absoluteURL
        } else {
            fullURL = baseURL.appendingPathComponent(path)
        }
        var request = URLRequest(url: fullURL)
        request.httpMethod = body == nil ? "GET" : "POST"
        request.timeoutInterval = 25
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(csrf, forHTTPHeaderField: "X-CSRF-Token")
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 {
            try? SessionVault.clear()
            user = nil; csrf = ""; self.baseURL = nil; dashboard = nil
            error = "Sua sessão expirou. Entre novamente."
        }
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(APIError.self, from: data).error) ?? "Não foi possível acessar o registro (\(status))."
            throw NSError(domain: "Smartcenter", code: status, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return data
    }

    private func message(for error: Error) -> String {
        if error is DecodingError { return "A resposta do servidor não corresponde à API do Smartcenter." }
        if let error = error as? URLError {
            switch error.code {
            case .notConnectedToInternet: return "Sem conexão com a internet."
            case .timedOut: return "O servidor demorou para responder. Tente novamente."
            default: return "Não foi possível conectar ao servidor. Confira o endereço e sua conexão."
            }
        }
        return error.localizedDescription
    }
}
