import Foundation

public struct Host: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var address: String
    public var port: Int
    public var username: String
    public var group: String
    public var tags: [String]
    public var note: String?
    public var favorite: Bool
    public var lastConnectedAt: Date?
    public var connectCount: Int
    public var auth: HostAuth
    public var policies: HostPolicies

    public init(
        id: UUID = UUID(),
        name: String,
        address: String,
        port: Int = 22,
        username: String,
        group: String = "Default",
        tags: [String] = [],
        note: String? = nil,
        favorite: Bool = false,
        lastConnectedAt: Date? = nil,
        connectCount: Int = 0,
        auth: HostAuth,
        policies: HostPolicies = .init()
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.port = port
        self.username = username
        self.group = group
        self.tags = tags
        self.note = note
        self.favorite = favorite
        self.lastConnectedAt = lastConnectedAt
        self.connectCount = connectCount
        self.auth = auth
        self.policies = policies
    }
}

public struct HostAuth: Codable, Equatable, Sendable {
    public var method: AuthenticationMethod
    public var keyReference: String?
    public var passwordReference: String?

    public init(
        method: AuthenticationMethod,
        keyReference: String? = nil,
        passwordReference: String? = nil
    ) {
        self.method = method
        self.keyReference = keyReference
        self.passwordReference = passwordReference
    }
}

public enum AuthenticationMethod: String, Codable, Sendable {
    case password
    case privateKey
    case agent
}

public struct HostPolicies: Codable, Equatable, Sendable {
    public var keepAliveSeconds: Int
    public var connectTimeoutSeconds: Int
    public var terminalProfileID: String

    public init(
        keepAliveSeconds: Int = 30,
        connectTimeoutSeconds: Int = 10,
        terminalProfileID: String = "default"
    ) {
        self.keepAliveSeconds = keepAliveSeconds
        self.connectTimeoutSeconds = connectTimeoutSeconds
        self.terminalProfileID = terminalProfileID
    }
}
