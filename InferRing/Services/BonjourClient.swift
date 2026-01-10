//
import Foundation

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
final class BonjourClient: NSObject, BonjourClientProtocol {
    @ObservationIgnored
    private lazy var browser = NetServiceBrowser()
    @ObservationIgnored
    private var resolvingServices: [NetService] = []

    var nodes: [Node] = []
    var isSearching = false

    func startSearching() {
        stopSearching()
        nodes.removeAll()
        browser.delegate = self
        browser.searchForServices(ofType: "_http._tcp", inDomain: "local.")
        isSearching = true
    }

    func stopSearching() {
        isSearching = false
        browser.stop()
        for service in resolvingServices {
            service.delegate = nil
            service.stop()
        }
        resolvingServices.removeAll()
    }
}

extension BonjourClient: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        guard isSearching else { return }
        nodes.removeAll { $0.host == service.hostName }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        guard isSearching,
              service.name.hasPrefix(ServiceInfo.servicePrefix),
              service.name != ServiceInfo.bonjourName
            else { return }
        resolvingServices.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5.0)

    }
}

extension BonjourClient: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        resolvingServices.removeAll { $0 == sender }

        let addresses = sender.addresses?.compactMap { ipString(from: $0) }
        dprint("available addresses")
        dprint(addresses)
        let ipAddress = addresses?.first { !$0.hasPrefix("192.") && !$0.hasPrefix("fe80:") } ?? addresses?.first { $0.hasPrefix("192.") }
        if let host = ipAddress ?? sender.hostName {
            nodes.removeAll { $0.host == host }
            nodes.append(Node(name: sender.name, host: host))
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        resolvingServices.removeAll { $0 == sender }
    }

    private func ipString(from addressData: Data) -> String? {
        return addressData.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> String? in
            guard let base = rawBuffer.baseAddress else { return nil }
            let family = base.assumingMemoryBound(to: sockaddr.self).pointee.sa_family
            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                base.assumingMemoryBound(to: sockaddr.self),
                socklen_t(addressData.count),
                &hostBuffer,
                socklen_t(hostBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if result == 0 {
                return String(cString: hostBuffer)
            }
            else {
                return nil
            }
        }
    }
}

