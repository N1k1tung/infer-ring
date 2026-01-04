//
import Foundation

@Observable
final class BonjourServer: NSObject {
    @ObservationIgnored
    private var service: NetService?
    @ObservationIgnored
    private var resolver: NetService?

    var isReachable: Bool = false

    override init() {
        super.init()

        registerBonjour(name: ServiceInfo.bonjourName, port: Int32(ServiceInfo.port))
    }

    func registerBonjour(name: String, type: String = "_http._tcp.", domain: String = "local.", port: Int32) {
        let publishName = name.trimmed.nilIfEmpty() ?? "InferRing Server"
        let netService = NetService(domain: domain, type: type, name: publishName, port: port)
        netService.includesPeerToPeer = true
        netService.delegate = self
        self.service = netService
        netService.publish(options: [])

        let resolver = NetService(domain: domain, type: type, name: publishName, port: port)
        resolver.includesPeerToPeer = true
        resolver.delegate = self
        self.resolver = resolver
    }

    deinit {
        stop()
    }

    func stop() {
        service?.stop()
        resolver?.stop()
        service = nil
        resolver = nil
    }
}

extension BonjourServer: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        resolver?.resolve(withTimeout: 5.0)
        dprint("Bonjour registration complete for: \(sender.name) \(sender.type) on \(sender.domain)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        dprint("Bonjour registration error: \(errorDict)")
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        if let host = sender.hostName, sender.port > 0 {
            let scheme = sender.type.contains("_https") ? "https" : "http"
            let urlString = "\(scheme)://\(host):\(sender.port)/"
            dprint("Service now locally reachable at: \(urlString)")
            isReachable = true
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        dprint("Bonjour resolution error: \(errorDict)")
    }
}
