//
import Foundation
import Network
import Observation

struct Node: Hashable {
    let name: String
    let host: String
    let interface: NWInterface
}

protocol BonjourClientProtocol: Observable {
    var nodes: [Node] { get }
    var isSearching: Bool { get }
    func startSearching()
    func stopSearching()
}

@Observable
final class BonjourClient: BonjourClientProtocol {
    
    @ObservationIgnored
    private var browser: NWBrowser?
    
    @ObservationIgnored
    private var resolvers: [String: [IPResolver]] = [:]
    
    var nodes: [Node] = []
    var isSearching = false
    var permissionDenied = false

    private static let kDNSServiceErr_PolicyDenied = -65570

    func startSearching() {
        stopSearching()
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: "local.")
        let browser = NWBrowser(for: descriptor, using: parameters)
        
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handleResults(results)
        }
        browser.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .failed(let error):
                if case .dns(let code) = error, code == Self.kDNSServiceErr_PolicyDenied {
                    dprint("Bonjour: Permission denied (failed)")
                    permissionDenied = true
                }
            case .waiting(let error):
                if case .dns(let code) = error, code == Self.kDNSServiceErr_PolicyDenied {
                    print("Bonjour: Permission denied (waiting)")
                    permissionDenied = true
                }
            case .ready:
                permissionDenied = false
            default:
                break
            }
        }

        self.browser = browser
        browser.start(queue: .main)
        isSearching = true
    }

    func stopSearching() {
        isSearching = false
        browser?.cancel()
        browser = nil
        resolvers.values.flatMap { $0 }.forEach { $0.cancel() }
        resolvers.removeAll()
    }
    
    private func handleResults(_ results: Set<NWBrowser.Result>) {
        var currentNames: Set<String> = []
        
        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint else { continue }

            guard name.hasPrefix(ServiceInfo.servicePrefix),
                  name != ServiceInfo.bonjourName
            else { continue }

            currentNames.insert(name)

            if !nodes.contains(where: { $0.name == name }) {
                resolve(result, name: name)
            }
        }
        
        // cleanup absent nodes & resolvers
        nodes.removeAll { !currentNames.contains($0.name) }
        for name in resolvers.keys {
            if !currentNames.contains(name) {
                resolvers[name]?.forEach { $0.cancel() }
                resolvers[name] = nil
            }
        }
    }
    
    private func resolve(_ result: NWBrowser.Result, name: String) {
        let sortedInterfaces = result.interfaces.sorted(by: <)

        if resolvers[name] == nil {
            resolvers[name] = []
        }

        for interface in sortedInterfaces {
            if let active = resolvers[name], active.contains(where: { $0.interface == interface }) {
                continue
            }
            
            let resolver = IPResolver(endpoint: result.endpoint, interface: interface) { [weak self] resolvedIP, usedInterface in
                self?.handleResolutionSuccess(name: name, ip: resolvedIP, interface: usedInterface)
            }
            
            resolver.onEnded = { [weak self, weak resolver] in
                guard let self, let resolver else { return }
                removeResolver(resolver, name: name)
            }
            
            resolvers[name]?.append(resolver)
            resolver.start()
        }
    }
    
    private func handleResolutionSuccess(name: String, ip: String, interface: NWInterface) {
        if let index = nodes.firstIndex(where: { $0.name == name }) {
            if nodes[index].host != ip && interface <= nodes[index].interface {
                nodes[index] = Node(name: name, host: ip, interface: interface)
            }
        }
        else {
            nodes.append(Node(name: name, host: ip, interface: interface))
        }
    }
    
    private func removeResolver(_ resolver: IPResolver, name: String) {
        if var list = resolvers[name] {
            list.removeAll { $0 === resolver }
            resolvers[name] = list
            if list.isEmpty {
                resolvers[name] = nil
            }
        }
    }
}

private class IPResolver {
    let endpoint: NWEndpoint
    let interface: NWInterface
    let completion: (String, NWInterface) -> Void
    var onEnded: (() -> Void)?
    
    private var connection: NWConnection?
    private var isCancelled = false
    private var timer: Timer?
    
    init(endpoint: NWEndpoint, interface: NWInterface, completion: @escaping (String, NWInterface) -> Void) {
        self.endpoint = endpoint
        self.interface = interface
        self.completion = completion
    }
    
    func start() {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 2 // Does not fire
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)

        // MLX ring requires IPv4, it also works out of the box for http server
        if let ipOptions = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ipOptions.version = .v4
        }
        parameters.requiredInterface = interface

        connection = NWConnection(to: endpoint, using: parameters)
        connection?.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                extractIP()
            case .failed(let error):
                dprint("Bonjour Resolution Failed for \(endpoint) on \(interface)): \(error)")
                cancel()
            case .cancelled:
                break
            case .waiting(let error):
                dprint("Bonjour Resolution Waiting for \(endpoint): \(error)")
            case .preparing, .setup:
                break
            @unknown default:
                break
            }
        }
        
        connection?.start(queue: .main)

        // manual timeout instead of relying on tcp connectionTimeout
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            if !isCancelled {
                dprint("Bonjour Resolution Timed Out for \(endpoint) on \(String(describing: interface))")
                cancel()
            }
        }
    }
    
    private func extractIP() {
        guard let connection = connection, !isCancelled else { return }
        
        if let remote = connection.currentPath?.remoteEndpoint,
           case .hostPort(let host, _) = remote {
            
            switch host {
            case .ipv4(let ipv4):
                let rawAddress = "\(ipv4)"
                let ipString = rawAddress.split(separator: "%", maxSplits: 1).first.map(String.init) ?? rawAddress
                completion(ipString, interface)
                cancel()
            default:
                dprint("Resolved to non-IPv4: \(host)")
                cancel()
            }
        }
        else {
            cancel()
        }
    }
    
    func cancel() {
        if isCancelled { return }
        isCancelled = true
        timer?.invalidate()
        timer = nil
        connection?.cancel()
        connection = nil
        onEnded?()
    }
}

extension NWInterface {
    static func <(_ lhs: NWInterface, _ rhs: NWInterface) -> Bool {
        if lhs.type == .wiredEthernet { return true }
        if rhs.type == .wiredEthernet { return false }
        if lhs.type == .wifi { return true }
        if rhs.type == .wifi { return false }
        return false
    }
    static func <=(_ lhs: NWInterface, _ rhs: NWInterface) -> Bool {
        lhs < rhs || lhs == rhs
    }
}
