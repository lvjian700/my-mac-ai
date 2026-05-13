@preconcurrency import AVFoundation
import Foundation
import VoiceAudioProtocol

enum AudioBridgeError: Error {
  case microphonePermissionDenied
  case audioFormatAllocationFailed
  case audioConverterAllocationFailed
  case audioConversionFailed(String)
  case unsupportedOutputFrame(VoiceAudioFrame)
}

final class AudioBridge: @unchecked Sendable {
  private let writer: LockedFrameWriter
  private let sequenceCounter = SequenceCounter()
  private let inputEngine = AVAudioEngine()
  private let playerEngine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let realtimeSampleRate = 24_000.0
  private let realtimeChannelCount: AVAudioChannelCount = 1
  private lazy var realtimeFormat: AVAudioFormat = {
    guard let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: realtimeSampleRate,
      channels: realtimeChannelCount,
      interleaved: true
    ) else {
      preconditionFailure("failed to create Realtime audio format")
    }
    return format
  }()

  init(writer: LockedFrameWriter) {
    self.writer = writer
  }

  func run() throws {
    try writer.write(.activity("starting"))
    try requestMicrophoneAccess()
    try startPlayer()
    try startInputCapture()
    try writer.write(.activity("ready"))

    do {
      try readCommandLoop()
    } catch {
      try? writer.write(.error(String(describing: error)))
      throw error
    }

    stop()
    try writer.write(.activity("stopped"))
  }

  private func requestMicrophoneAccess() throws {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      return
    case .notDetermined:
      let semaphore = DispatchSemaphore(value: 0)
      let permissionResult = MicrophonePermissionResult()
      AVCaptureDevice.requestAccess(for: .audio) { accessGranted in
        permissionResult.setGranted(accessGranted)
        semaphore.signal()
      }
      semaphore.wait()
      if !permissionResult.granted {
        throw AudioBridgeError.microphonePermissionDenied
      }
    case .denied, .restricted:
      throw AudioBridgeError.microphonePermissionDenied
    @unknown default:
      throw AudioBridgeError.microphonePermissionDenied
    }
  }

  private func startPlayer() throws {
    playerEngine.attach(player)
    playerEngine.connect(
      player,
      to: playerEngine.mainMixerNode,
      format: realtimeFormat
    )
    playerEngine.prepare()
    try playerEngine.start()
    player.play()
  }

  private func startInputCapture() throws {
    let inputNode = inputEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)
    guard let converter = AVAudioConverter(from: inputFormat, to: realtimeFormat) else {
      throw AudioBridgeError.audioConverterAllocationFailed
    }

    inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) {
      [realtimeFormat, converter, sequenceCounter, writer] buffer,
      _ in
      do {
        let convertedBuffer = try Self.convert(
          buffer,
          to: realtimeFormat,
          using: converter
        )
        guard convertedBuffer.frameLength > 0 else {
          return
        }
        let audio = try PCMFloat32Codec.encode(convertedBuffer)
        let frame = VoiceAudioFrame.inputAudio(
          audio,
          sampleRate: Int(convertedBuffer.format.sampleRate),
          channels: Int(convertedBuffer.format.channelCount),
          format: PCMFloat32Codec.formatName,
          sequence: sequenceCounter.next()
        )
        try writer.write(frame)
      } catch {
        try? writer.write(.error(String(describing: error)))
      }
    }

    inputEngine.prepare()
    try inputEngine.start()
  }

  private static func convert(
    _ buffer: AVAudioPCMBuffer,
    to format: AVAudioFormat,
    using converter: AVAudioConverter
  ) throws -> AVAudioPCMBuffer {
    let ratio = format.sampleRate / buffer.format.sampleRate
    let capacity = max(1, AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1)
    guard let outputBuffer = AVAudioPCMBuffer(
      pcmFormat: format,
      frameCapacity: capacity
    ) else {
      throw AudioBridgeError.audioFormatAllocationFailed
    }

    let provider = OneShotAudioInputProvider(buffer: buffer)
    let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
      provider.next(outStatus: outStatus)
    }

    var conversionError: NSError?
    converter.convert(
      to: outputBuffer,
      error: &conversionError,
      withInputFrom: inputBlock
    )

    if let conversionError {
      throw AudioBridgeError.audioConversionFailed(conversionError.localizedDescription)
    }

    return outputBuffer
  }

  private func readCommandLoop() throws {
    while let frame = try VoiceAudioFrameCodec.readFrame(from: .standardInput) {
      switch frame.type {
      case .outputAudio:
        try play(frame)
      case .shutdown:
        return
      case .activity:
        try writer.write(.activity("ack:\(frame.activity ?? "activity")"))
      case .error:
        try writer.write(.error(frame.message ?? "upstream error"))
      case .inputAudio:
        try writer.write(.error("input_audio frames are emitted by cali-voice-audio"))
      }
    }
  }

  private func play(_ frame: VoiceAudioFrame) throws {
    guard let buffer = try PCMFloat32Codec.decode(frame) else {
      throw AudioBridgeError.unsupportedOutputFrame(frame)
    }

    player.scheduleBuffer(buffer)
    if !player.isPlaying {
      player.play()
    }
  }

  private func stop() {
    inputEngine.inputNode.removeTap(onBus: 0)
    inputEngine.stop()
    player.stop()
    playerEngine.stop()
  }
}

final class LockedFrameWriter: @unchecked Sendable {
  private let handle: FileHandle
  private let lock = NSLock()

  init(handle: FileHandle) {
    self.handle = handle
  }

  func write(_ frame: VoiceAudioFrame) throws {
    lock.lock()
    defer { lock.unlock() }
    try VoiceAudioFrameCodec.write(frame, to: handle)
  }
}

final class SequenceCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var value: UInt64 = 0

  func next() -> UInt64 {
    lock.lock()
    defer { lock.unlock() }
    let current = value
    value += 1
    return current
  }
}

final class MicrophonePermissionResult: @unchecked Sendable {
  private let lock = NSLock()
  private var value = false

  var granted: Bool {
    lock.lock()
    defer { lock.unlock() }
    return value
  }

  func setGranted(_ granted: Bool) {
    lock.lock()
    defer { lock.unlock() }
    value = granted
  }
}

final class OneShotAudioInputProvider: @unchecked Sendable {
  private let lock = NSLock()
  private let buffer: AVAudioPCMBuffer
  private var didProvideInput = false

  init(buffer: AVAudioPCMBuffer) {
    self.buffer = buffer
  }

  func next(
    outStatus: UnsafeMutablePointer<AVAudioConverterInputStatus>
  ) -> AVAudioBuffer? {
    lock.lock()
    defer { lock.unlock() }

    if didProvideInput {
      outStatus.pointee = .noDataNow
      return nil
    }

    didProvideInput = true
    outStatus.pointee = .haveData
    return buffer
  }
}
