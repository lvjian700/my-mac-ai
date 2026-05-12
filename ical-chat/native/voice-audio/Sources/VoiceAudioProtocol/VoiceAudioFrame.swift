import Foundation

public enum VoiceAudioEventType: String, Codable, CaseIterable, Sendable {
  case inputAudio = "input_audio"
  case outputAudio = "output_audio"
  case activity
  case shutdown
  case error
}

public struct VoiceAudioFrame: Equatable, Sendable {
  public var type: VoiceAudioEventType
  public var audio: Data?
  public var sampleRate: Int?
  public var channels: Int?
  public var format: String?
  public var sequence: UInt64?
  public var activity: String?
  public var message: String?

  public init(
    type: VoiceAudioEventType,
    audio: Data? = nil,
    sampleRate: Int? = nil,
    channels: Int? = nil,
    format: String? = nil,
    sequence: UInt64? = nil,
    activity: String? = nil,
    message: String? = nil
  ) {
    self.type = type
    self.audio = audio
    self.sampleRate = sampleRate
    self.channels = channels
    self.format = format
    self.sequence = sequence
    self.activity = activity
    self.message = message
  }

  public static func inputAudio(
    _ audio: Data,
    sampleRate: Int,
    channels: Int,
    format: String = "f32le",
    sequence: UInt64? = nil
  ) -> VoiceAudioFrame {
    VoiceAudioFrame(
      type: .inputAudio,
      audio: audio,
      sampleRate: sampleRate,
      channels: channels,
      format: format,
      sequence: sequence
    )
  }

  public static func outputAudio(
    _ audio: Data,
    sampleRate: Int,
    channels: Int,
    format: String = "f32le",
    sequence: UInt64? = nil
  ) -> VoiceAudioFrame {
    VoiceAudioFrame(
      type: .outputAudio,
      audio: audio,
      sampleRate: sampleRate,
      channels: channels,
      format: format,
      sequence: sequence
    )
  }

  public static func activity(_ activity: String) -> VoiceAudioFrame {
    VoiceAudioFrame(type: .activity, activity: activity)
  }

  public static func shutdown(message: String? = nil) -> VoiceAudioFrame {
    VoiceAudioFrame(type: .shutdown, message: message)
  }

  public static func error(_ message: String) -> VoiceAudioFrame {
    VoiceAudioFrame(type: .error, message: message)
  }
}

extension VoiceAudioFrame: Codable {
  private enum CodingKeys: String, CodingKey {
    case type
    case audio
    case sampleRate = "sample_rate"
    case channels
    case format
    case sequence
    case activity
    case message
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    type = try container.decode(VoiceAudioEventType.self, forKey: .type)
    sampleRate = try container.decodeIfPresent(Int.self, forKey: .sampleRate)
    channels = try container.decodeIfPresent(Int.self, forKey: .channels)
    format = try container.decodeIfPresent(String.self, forKey: .format)
    sequence = try container.decodeIfPresent(UInt64.self, forKey: .sequence)
    activity = try container.decodeIfPresent(String.self, forKey: .activity)
    message = try container.decodeIfPresent(String.self, forKey: .message)

    if let encodedAudio = try container.decodeIfPresent(String.self, forKey: .audio) {
      guard let decodedAudio = Data(base64Encoded: encodedAudio) else {
        throw DecodingError.dataCorruptedError(
          forKey: .audio,
          in: container,
          debugDescription: "Expected base64-encoded audio payload"
        )
      }
      audio = decodedAudio
    } else {
      audio = nil
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(type, forKey: .type)
    try container.encodeIfPresent(audio?.base64EncodedString(), forKey: .audio)
    try container.encodeIfPresent(sampleRate, forKey: .sampleRate)
    try container.encodeIfPresent(channels, forKey: .channels)
    try container.encodeIfPresent(format, forKey: .format)
    try container.encodeIfPresent(sequence, forKey: .sequence)
    try container.encodeIfPresent(activity, forKey: .activity)
    try container.encodeIfPresent(message, forKey: .message)
  }
}
