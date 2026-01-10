//
import Foundation
import Network
import Observation

struct Node: Hashable {
    let name: String
    let host: String
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
    private var resolvers: [String: IPResolver] = [:]
    
    var nodes: [Node] = []
    var isSearching = false

    func startSearching() {
        stopSearching()
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: "local.")
        let browser = NWBrowser(for: descriptor, using: parameters)
        
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handleResults(results)
        }
        
        self.browser = browser
        browser.start(queue: .main)
        isSearching = true
    }

    func stopSearching() {
        isSearching = false
        browser?.cancel()
        browser = nil
        resolvers.values.forEach { $0.cancel() }
        resolvers.removeAll()
    }
    
    private func handleResults(_ results: Set<NWBrowser.Result>) {
        var currentNames: Set<String> = []
        
        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint else { continue }
            
            guard name.hasPrefix(ServiceInfo.servicePrefix),
                  name != ServiceInfo.bonjourName else { continue }
            
            currentNames.insert(name)
            
            // check if we already have a stable node for this
            if resolvers[name] == nil && !nodes.contains(where: { $0.name == name }) {
                resolve(result)
            }
        }
        
        // cleanup absent nodes & resolvers
        nodes.removeAll { !currentNames.contains($0.name) }
        for (name, resolver) in resolvers {
            if !currentNames.contains(name) {
                resolver.cancel()
                resolvers.removeValue(forKey: name)
            }
        }
    }
    
    private func resolve(_ result: NWBrowser.Result) {
        guard case .service(let name, _, _, _) = result.endpoint else { return }
        
        let sortedInterfaces = result.interfaces.sorted { lhs, rhs in
            if lhs.type == .wiredEthernet { return true }
            if rhs.type == .wiredEthernet { return false }
            if lhs.type == .wifi { return true }
            if rhs.type == .wifi { return false }
            return false
        }
        
        let targetInterface = sortedInterfaces.first
        
        let resolver = IPResolver(endpoint: result.endpoint, interface: targetInterface) { [weak self] resolvedIP in
            guard let self else { return }
            
            if let index = nodes.firstIndex(where: { $0.name == name }) {
                if nodes[index].host != resolvedIP {
                     nodes[index] = Node(name: name, host: resolvedIP)
                }
            }
            else {
                nodes.append(Node(name: name, host: resolvedIP))
            }
            
            resolvers.removeValue(forKey: name)
        }
        
        resolvers[name] = resolver
        resolver.start()
    }
}

private class IPResolver {
    let endpoint: NWEndpoint
    let interface: NWInterface?
    let completion: (String) -> Void
    private var connection: NWConnection?
    private var isCancelled = false
    
    init(endpoint: NWEndpoint, interface: NWInterface?, completion: @escaping (String) -> Void) {
        self.endpoint = endpoint
        self.interface = interface
        self.completion = completion
    }
    
    func start() {
        let tcpOptions = NWProtocolTCP.Options()
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
                dprint("Bonjour Resolution Failed for \(endpoint): \(error)")
                cancel()
            case .cancelled:
                break
            case .waiting(let error):
                dprint("Bonjour Resolution Waiting for \(endpoint): \(error)")
            default:
                break
            }
        }
        
        connection?.start(queue: .main)
    }
    
    private func extractIP() {
        guard let connection = connection, !isCancelled else { return }
        
        if let remote = connection.currentPath?.remoteEndpoint,
           case .hostPort(let host, _) = remote {
            
            switch host {
            case .ipv4(let ipv4):
                let rawAddress = "\(ipv4)"
                let ipString = rawAddress.split(separator: "%", maxSplits: 1).first.map(String.init) ?? rawAddress
                completion(ipString)
                cancel()
            default:
                dprint("Resolved to non-IPv4: \(host)")
                cancel()
            }
        }
    }
    
    func cancel() {
        isCancelled = true
        connection?.cancel()
        connection = nil
    }
}

