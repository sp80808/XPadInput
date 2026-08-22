import Foundation
import os

struct State { var x: Int = 0 }
let lock = OSAllocatedUnfairLock(initialState: State())
lock.withLock { $0.x += 1 }
if let x = lock.withLockIfAvailable({ $0.x }) {
    print("X: \(x)")
}
