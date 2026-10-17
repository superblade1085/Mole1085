import Foundation

public struct MoleCore {
    public static let minimumOSVersion = "14.0"
    
    public static var isSupportedPlatform: Bool {
        #if os(macOS)
        if #available(macOS 14.0, *) {
            return true
        } else {
            return false
        }
        #else
        return false
        #endif
    }
    
    public init() {}
}
