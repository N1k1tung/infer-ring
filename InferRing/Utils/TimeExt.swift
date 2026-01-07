//
import Foundation

nonisolated(unsafe) private var timebase = mach_timebase_info_data_t()

@inline(__always)
func timeNs() -> UInt64 {
    if timebase.denom == 0 {
        mach_timebase_info(&timebase)
    }
    let t = mach_absolute_time()
    return t &* UInt64(timebase.numer) / UInt64(timebase.denom)
}

func measure(_ closure: () async throws -> Void) async rethrows -> TimeInterval {
    let start = timeNs()
    try await closure()
    return TimeInterval(timeNs() - start) / 1_000_000_000.0
}
