import Foundation

public enum VoiceAudioFrameCodecError: Error, Equatable, Sendable {
  case incompleteLengthPrefix(byteCount: Int)
  case incompletePayload(expectedByteCount: Int, actualByteCount: Int)
  case frameTooLarge(byteCount: Int, maxByteCount: Int)
  case trailingBytes(byteCount: Int)
}

public enum VoiceAudioFrameCodec {
  public static let lengthPrefixByteCount = 4
  public static let defaultMaxFrameByteCount = 16 * 1024 * 1024

  public static var jsonEncoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  public static var jsonDecoder: JSONDecoder {
    JSONDecoder()
  }

  public static func encode(
    _ frame: VoiceAudioFrame,
    encoder: JSONEncoder = VoiceAudioFrameCodec.jsonEncoder
  ) throws -> Data {
    let payload = try encodePayload(frame, encoder: encoder)
    guard payload.count <= UInt32.max else {
      throw VoiceAudioFrameCodecError.frameTooLarge(
        byteCount: payload.count,
        maxByteCount: Int(UInt32.max)
      )
    }

    var length = UInt32(payload.count).bigEndian
    var frameData = Data()
    withUnsafeBytes(of: &length) { lengthBytes in
      frameData.append(contentsOf: lengthBytes)
    }
    frameData.append(payload)
    return frameData
  }

  public static func decode(
    _ data: Data,
    maxFrameByteCount: Int = VoiceAudioFrameCodec.defaultMaxFrameByteCount,
    decoder: JSONDecoder = VoiceAudioFrameCodec.jsonDecoder
  ) throws -> VoiceAudioFrame {
    guard data.count >= lengthPrefixByteCount else {
      throw VoiceAudioFrameCodecError.incompleteLengthPrefix(byteCount: data.count)
    }

    let payloadLength = Int(readLengthPrefix(from: data))
    guard payloadLength <= maxFrameByteCount else {
      throw VoiceAudioFrameCodecError.frameTooLarge(
        byteCount: payloadLength,
        maxByteCount: maxFrameByteCount
      )
    }

    let expectedByteCount = lengthPrefixByteCount + payloadLength
    guard data.count >= expectedByteCount else {
      throw VoiceAudioFrameCodecError.incompletePayload(
        expectedByteCount: payloadLength,
        actualByteCount: data.count - lengthPrefixByteCount
      )
    }
    guard data.count == expectedByteCount else {
      throw VoiceAudioFrameCodecError.trailingBytes(byteCount: data.count - expectedByteCount)
    }

    return try decodePayload(
      data.subdata(in: lengthPrefixByteCount..<expectedByteCount),
      decoder: decoder
    )
  }

  public static func encodePayload(
    _ frame: VoiceAudioFrame,
    encoder: JSONEncoder = VoiceAudioFrameCodec.jsonEncoder
  ) throws -> Data {
    try encoder.encode(frame)
  }

  public static func decodePayload(
    _ data: Data,
    decoder: JSONDecoder = VoiceAudioFrameCodec.jsonDecoder
  ) throws -> VoiceAudioFrame {
    try decoder.decode(VoiceAudioFrame.self, from: data)
  }

  public static func readFrame(
    from handle: FileHandle,
    maxFrameByteCount: Int = VoiceAudioFrameCodec.defaultMaxFrameByteCount,
    decoder: JSONDecoder = VoiceAudioFrameCodec.jsonDecoder
  ) throws -> VoiceAudioFrame? {
    guard let lengthPrefix = readExactly(lengthPrefixByteCount, from: handle) else {
      return nil
    }
    guard lengthPrefix.count == lengthPrefixByteCount else {
      throw VoiceAudioFrameCodecError.incompleteLengthPrefix(byteCount: lengthPrefix.count)
    }

    let payloadLength = Int(readLengthPrefix(from: lengthPrefix))
    guard payloadLength <= maxFrameByteCount else {
      throw VoiceAudioFrameCodecError.frameTooLarge(
        byteCount: payloadLength,
        maxByteCount: maxFrameByteCount
      )
    }

    guard let payload = readExactly(payloadLength, from: handle) else {
      throw VoiceAudioFrameCodecError.incompletePayload(
        expectedByteCount: payloadLength,
        actualByteCount: 0
      )
    }
    guard payload.count == payloadLength else {
      throw VoiceAudioFrameCodecError.incompletePayload(
        expectedByteCount: payloadLength,
        actualByteCount: payload.count
      )
    }

    return try decodePayload(payload, decoder: decoder)
  }

  public static func write(
    _ frame: VoiceAudioFrame,
    to handle: FileHandle,
    encoder: JSONEncoder = VoiceAudioFrameCodec.jsonEncoder
  ) throws {
    try handle.write(contentsOf: encode(frame, encoder: encoder))
  }

  static func readLengthPrefix(from data: Data) -> UInt32 {
    data.prefix(lengthPrefixByteCount).reduce(UInt32(0)) { partial, byte in
      (partial << 8) | UInt32(byte)
    }
  }

  private static func readExactly(_ byteCount: Int, from handle: FileHandle) -> Data? {
    var data = Data()
    while data.count < byteCount {
      let chunk = handle.readData(ofLength: byteCount - data.count)
      if chunk.isEmpty {
        return data.isEmpty ? nil : data
      }
      data.append(chunk)
    }
    return data
  }
}

public struct VoiceAudioFrameStreamDecoder: Sendable {
  private var buffer = Data()
  private let maxFrameByteCount: Int
  private let decoder: JSONDecoder

  public init(
    maxFrameByteCount: Int = VoiceAudioFrameCodec.defaultMaxFrameByteCount,
    decoder: JSONDecoder = VoiceAudioFrameCodec.jsonDecoder
  ) {
    self.maxFrameByteCount = maxFrameByteCount
    self.decoder = decoder
  }

  public mutating func append(_ data: Data) throws -> [VoiceAudioFrame] {
    buffer.append(data)
    var frames: [VoiceAudioFrame] = []

    while buffer.count >= VoiceAudioFrameCodec.lengthPrefixByteCount {
      let payloadLength = Int(VoiceAudioFrameCodec.readLengthPrefix(from: buffer))
      guard payloadLength <= maxFrameByteCount else {
        throw VoiceAudioFrameCodecError.frameTooLarge(
          byteCount: payloadLength,
          maxByteCount: maxFrameByteCount
        )
      }

      let frameByteCount = VoiceAudioFrameCodec.lengthPrefixByteCount + payloadLength
      guard buffer.count >= frameByteCount else {
        break
      }

      let payload = buffer.subdata(
        in: VoiceAudioFrameCodec.lengthPrefixByteCount..<frameByteCount
      )
      frames.append(try VoiceAudioFrameCodec.decodePayload(payload, decoder: decoder))
      buffer.removeSubrange(0..<frameByteCount)
    }

    return frames
  }
}
