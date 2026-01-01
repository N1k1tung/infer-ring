//
import Foundation
import Darwin

public func initMlx() {
    setenv("MLX_HOSTFILE", "", 1)
    setenv("MLX_RANK", "", 1)
}
