import Foundation
import MoleCore
import MoleHelper

let delegate = HelperDaemon()
let listener = NSXPCListener(machServiceName: HelperDaemon.machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
