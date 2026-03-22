//
import SwiftUI
#if os(iOS)
import UIKit

typealias PlatformImage = UIImage

extension PlatformImage {
    static func chatAttachment(at url: URL) -> PlatformImage? {
        PlatformImage(contentsOfFile: url.path)
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}
#else
import AppKit

typealias PlatformImage = NSImage

extension PlatformImage {
    static func chatAttachment(at url: URL) -> PlatformImage? {
        PlatformImage(contentsOf: url)
    }
}

extension Image {
    init(platformImage: PlatformImage) {
        self.init(nsImage: platformImage)
    }
}
#endif
