import Foundation

let writer = LockedFrameWriter(handle: .standardOutput)
let bridge = AudioBridge(writer: writer)

do {
  try bridge.run()
} catch {
  try? writer.write(.error(String(describing: error)))
  Foundation.exit(1)
}
