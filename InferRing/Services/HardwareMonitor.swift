import Foundation
import MLX

final class HardwareMonitor {
    
    // MARK: - Properties
    
    private(set) lazy var currentProfile: HardwareProfile = .from(gpuInfo: GPU.deviceInfo())
    private let updateInterval: TimeInterval = 5.0
    @ObservationIgnored
    private var monitoringTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        // for now no need for live updates, we only track max ram amounts
//        startMonitoring()
        Memory.memoryLimit = currentProfile.recommendedUsageRAM
#if os(iOS)
        Memory.cacheLimit = currentProfile.recommendedUsageRAM / 2
#endif
    }
    
    deinit {
        stopMonitoring()
    }

    // MARK: - Private Methods
    
    private func startMonitoring() {
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.updateProfile()
                try? await Task.sleep(nanoseconds: UInt64(self?.updateInterval ?? 5.0 * 1_000_000_000))
            }
        }
    }
    
    private func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    func updateProfile() {
        currentProfile = .from(gpuInfo: GPU.deviceInfo())
    }
}

extension HardwareProfile {
    static func from(gpuInfo: GPU.DeviceInfo) -> Self {
        #if os(iOS)
        .init(
            totalRAM: gpuInfo.memorySize,
            recommendedUsageRAM: Int(Double(gpuInfo.maxRecommendedWorkingSetSize) * 0.7), // in practice iOS watchdog will kill when allocating as much as recommended set size
            idiom: .current
        )
        #else
        .init(
            totalRAM: gpuInfo.memorySize,
            recommendedUsageRAM: Int(gpuInfo.maxRecommendedWorkingSetSize),
            idiom: .current
        )
        #endif
    }
}
