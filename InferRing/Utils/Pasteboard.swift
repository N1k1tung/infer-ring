//

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct Pasteboard {
    static func setText(_ text: String) {
#if os(iOS)
        UIPasteboard.general.string = text
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([text as NSString])
#endif
    }
}
