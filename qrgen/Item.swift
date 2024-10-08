import Foundation
import SwiftData

@Model
final class Item {
    var name: String?
    var timestamp: Date
    var qrContent: QRMode = QRMode.url("")

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
