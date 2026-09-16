import Foundation

public enum GestureButtonCatalog {
    public struct Option: Equatable {
        public var id: String
        public var title: String
        public var cids: [UInt16]
    }

    public static let options: [Option] = [
        Option(id: "gesture", title: "Gesture", cids: ReprogControls.preferredGestureCIDs),
        Option(id: "back", title: "Back", cids: [0x0053]),
        Option(id: "forward", title: "Forward", cids: [0x0056]),
        Option(id: "middle", title: "Middle", cids: [0x0052]),
        Option(id: "smartShift", title: "Smart Shift", cids: [0x00C4])
    ]

    public static func isSelected(_ option: Option, cids: [UInt16]) -> Bool {
        if cids.isEmpty {
            return option.id == "gesture"
        }
        return option.cids.contains { cids.contains($0) }
    }

    public static func cids(fromSelectedIDs ids: Set<String>) -> [UInt16] {
        options.filter { ids.contains($0.id) }.flatMap(\.cids)
    }

    public static func summary(cids: [UInt16]) -> String {
        let selected = options.filter { isSelected($0, cids: cids) }
        if !selected.isEmpty {
            return selected.map(\.title).joined(separator: ", ")
        }
        return cids.map { "0x\(String($0, radix: 16))" }.joined(separator: ", ")
    }
}
