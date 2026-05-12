import Foundation
import XCTest
@testable import VoiceAudioProtocol

final class VoiceAudioFrameCodecTests: XCTestCase {
  func testEncodesAndDecodesInputAudioFrame() throws {
    let audio = Data([0x00, 0x01, 0x02, 0x03, 0xfe, 0xff])
    let frame = VoiceAudioFrame.inputAudio(
      audio,
      sampleRate: 48_000,
      channels: 2,
      sequence: 42
    )

    let encoded = try VoiceAudioFrameCodec.encode(frame)
    XCTAssertEqual(encoded.prefix(4), Data([0x00, 0x00, 0x00, UInt8(encoded.count - 4)]))

    let decoded = try VoiceAudioFrameCodec.decode(encoded)
    XCTAssertEqual(decoded, frame)

    let payload = try VoiceAudioFrameCodec.encodePayload(frame)
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
    XCTAssertEqual(json["type"] as? String, "input_audio")
    XCTAssertEqual(json["audio"] as? String, audio.base64EncodedString())
    XCTAssertEqual(json["sample_rate"] as? Int, 48_000)
    XCTAssertEqual(json["channels"] as? Int, 2)
    XCTAssertEqual(json["format"] as? String, "f32le")
    XCTAssertEqual(json["sequence"] as? Int, 42)
  }

  func testEncodesAndDecodesAllEventTypes() throws {
    let frames: [VoiceAudioFrame] = [
      .inputAudio(Data([1, 2, 3, 4]), sampleRate: 16_000, channels: 1),
      .outputAudio(Data([5, 6, 7, 8]), sampleRate: 24_000, channels: 2, sequence: 7),
      .activity("ready"),
      .shutdown(message: "bye"),
      .error("microphone unavailable"),
    ]

    for frame in frames {
      XCTAssertEqual(try VoiceAudioFrameCodec.decode(VoiceAudioFrameCodec.encode(frame)), frame)
    }
  }

  func testStreamDecoderHandlesPartialAndMultipleFrames() throws {
    let first = VoiceAudioFrame.activity("starting")
    let second = VoiceAudioFrame.error("bad input")
    let encoded = try VoiceAudioFrameCodec.encode(first) + VoiceAudioFrameCodec.encode(second)
    let splitIndex = 6

    var decoder = VoiceAudioFrameStreamDecoder()
    XCTAssertEqual(try decoder.append(encoded.prefix(splitIndex)), [])
    XCTAssertEqual(try decoder.append(encoded.dropFirst(splitIndex)), [first, second])
  }

  func testDecodeRejectsTrailingBytes() throws {
    var encoded = try VoiceAudioFrameCodec.encode(.shutdown())
    encoded.append(0xff)

    XCTAssertThrowsError(try VoiceAudioFrameCodec.decode(encoded)) { error in
      XCTAssertEqual(error as? VoiceAudioFrameCodecError, .trailingBytes(byteCount: 1))
    }
  }

  func testDecodeRejectsInvalidBase64AudioPayload() throws {
    let payload = Data(#"{"type":"input_audio","audio":"not-base64!!!"}"#.utf8)
    var length = UInt32(payload.count).bigEndian
    var encoded = Data()
    withUnsafeBytes(of: &length) { encoded.append(contentsOf: $0) }
    encoded.append(payload)

    XCTAssertThrowsError(try VoiceAudioFrameCodec.decode(encoded))
  }
}
