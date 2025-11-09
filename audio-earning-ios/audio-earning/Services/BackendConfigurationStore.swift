//
//  BackendConfigurationStore.swift
//  audio-earning
//
//  Created by Codex on 2025/11/01.
//

import Foundation

extension Notification.Name {
    static let backendConfigurationDidChange = Notification.Name("backendConfigurationDidChange")
}

struct BackendEndpoint: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var url: URL
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, url: URL, isBuiltIn: Bool) {
        self.id = id
        self.name = name
        self.url = url
        self.isBuiltIn = isBuiltIn
    }
}

final class BackendConfigurationStore {
    static let shared = BackendConfigurationStore()

    private let defaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private let endpointsKey = "backend.endpoints"
    private let activeEndpointIDKey = "backend.activeEndpointID"
    private let legacyOverrideKey = "backend.baseURL.override"

    private var cachedEndpoints: [BackendEndpoint] = []
    private var activeEndpointID: UUID?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let state = loadInitialState()
        cachedEndpoints = state.endpoints
        activeEndpointID = state.activeID
    }

    var endpoints: [BackendEndpoint] {
        cachedEndpoints
    }

    var currentEndpoint: BackendEndpoint {
        if let activeEndpointID,
           let endpoint = cachedEndpoints.first(where: { $0.id == activeEndpointID }) {
            return endpoint
        }

        guard let first = cachedEndpoints.first else {
            let defaults = makeDefaultEndpoints()
            cachedEndpoints = defaults
            activeEndpointID = defaults.first?.id
            persistState()
            return defaults.first!
        }

        activeEndpointID = first.id
        persistState()
        return first
    }

    func selectEndpoint(id: UUID) {
        guard cachedEndpoints.contains(where: { $0.id == id }) else { return }
        activeEndpointID = id
        persistState()
        notifyChange()
    }

    @discardableResult
    func addOrUpdateEndpoint(name: String, url: URL, select: Bool = true) -> BackendEndpoint {
        let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Self.displayName(for: url) : name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = cachedEndpoints.firstIndex(where: { $0.url.normalized == url.normalized }) {
            var endpoint = cachedEndpoints[index]
            endpoint.name = resolvedName
            cachedEndpoints[index] = endpoint
            if select {
                activeEndpointID = endpoint.id
            }
            persistState()
            notifyChange()
            return endpoint
        }

        let endpoint = BackendEndpoint(name: resolvedName, url: url, isBuiltIn: false)
        cachedEndpoints.append(endpoint)
        if select {
            activeEndpointID = endpoint.id
        }
        persistState()
        notifyChange()
        return endpoint
    }

    func deleteEndpoint(id: UUID) {
        guard cachedEndpoints.count > 1 else { return }
        guard let index = cachedEndpoints.firstIndex(where: { $0.id == id }) else { return }
        let endpoint = cachedEndpoints[index]

        cachedEndpoints.remove(at: index)

        if activeEndpointID == endpoint.id {
            let fallback = cachedEndpoints.first
            activeEndpointID = fallback?.id
        }

        persistState()
        notifyChange()
    }

    func canDeleteEndpoint(_ endpoint: BackendEndpoint) -> Bool {
        cachedEndpoints.count > 1
    }

    // MARK: - Backup & Restore

    /// 導出後端配置（用於備份）
    func exportConfiguration() -> (endpoints: [BackendEndpoint], activeID: UUID?) {
        return (cachedEndpoints, activeEndpointID)
    }

    /// 導入後端配置（完全覆蓋現有資料）
    func importConfiguration(endpoints: [BackendEndpoint], activeID: UUID?) {
        cachedEndpoints = endpoints
        activeEndpointID = activeID
        persistState()
        notifyChange()
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .backendConfigurationDidChange, object: nil)
    }

    private func loadInitialState() -> (endpoints: [BackendEndpoint], activeID: UUID?) {
        if let data = defaults.data(forKey: endpointsKey),
           let decoded = try? decoder.decode([BackendEndpoint].self, from: data),
           !decoded.isEmpty {
            let activeID = defaults.string(forKey: activeEndpointIDKey).flatMap(UUID.init(uuidString:))
            return (decoded, activeID)
        }

        var endpoints = makeDefaultEndpoints()
        var activeID = endpoints.first?.id

        if let legacyString = defaults.string(forKey: legacyOverrideKey),
           let legacyURL = URL(string: legacyString) {
            defaults.removeObject(forKey: legacyOverrideKey)
            if let index = endpoints.firstIndex(where: { $0.url.normalized == legacyURL.normalized }) {
                activeID = endpoints[index].id
            } else {
                let custom = BackendEndpoint(name: Self.displayName(for: legacyURL), url: legacyURL, isBuiltIn: false)
                endpoints.append(custom)
                activeID = custom.id
            }
        }

        cachedEndpoints = endpoints
        activeEndpointID = activeID
        persistState()
        return (endpoints, activeID)
    }

    private func makeDefaultEndpoints() -> [BackendEndpoint] {
        var endpoints: [BackendEndpoint] = []
        if let production = Self.productionEndpointURL {
            endpoints.append(BackendEndpoint(name: "Production", url: production, isBuiltIn: true))
        }

        if let local = Self.localDevelopmentURL {
            endpoints.append(BackendEndpoint(name: "Local Development", url: local, isBuiltIn: true))
        }

        return endpoints
    }

    private static let productionEndpointURL = URL(string: "https://storytelling-backend-qiuj.onrender.com")
    private static let localDevelopmentURL = URL(string: "http://127.0.0.1:8000")

    @discardableResult
    func updateEndpoint(id: UUID, name: String, url: URL) -> BackendEndpoint? {
        guard let index = cachedEndpoints.firstIndex(where: { $0.id == id }) else { return nil }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? Self.displayName(for: url) : trimmedName

        var endpoint = cachedEndpoints[index]
        endpoint.name = resolvedName
        endpoint.url = url
        endpoint.isBuiltIn = false
        cachedEndpoints[index] = endpoint

        persistState()
        notifyChange()
        return endpoint
    }

    private func persistState() {
        if let data = try? encoder.encode(cachedEndpoints) {
            defaults.set(data, forKey: endpointsKey)
        }
        defaults.set(activeEndpointID?.uuidString, forKey: activeEndpointIDKey)
    }

    private static func displayName(for url: URL) -> String {
        if let host = url.host, !host.isEmpty {
            return host
        }
        return url.absoluteString
    }
}

private extension URL {
    var normalized: String {
        absoluteString
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
    }
}
