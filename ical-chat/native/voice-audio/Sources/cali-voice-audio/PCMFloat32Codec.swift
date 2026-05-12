@preconcurrency import AVFoundation
import Foundation
import VoiceAudioProtocol

enum PCMFloat32CodecError: Error {
  case unsupportedInputFormat(AVAudioCommonFormat)
  case missingChannelData
  case invalidOutputMetadata
  case invalidOutputPayload(byteCount: Int, channels: Int)
  case outputBufferAllocationFailed
}

enum PCMFloat32Codec {
  static let formatName = "f32le"

  static func encode(_ buffer: AVAudioPCMBuffer) throws -> Data {
    guard buffer.format.commonFormat == .pcmFormatFloat32 else {
      throw PCMFloat32CodecError.unsupportedInputFormat(buffer.format.commonFormat)
    }
    guard let channelData = buffer.floatChannelData else {
      throw PCMFloat32CodecError.missingChannelData
    }

    let frameCount = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)
    var samples = [Float](repeating: 0, count: frameCount * channelCount)

    if buffer.format.isInterleaved {
      let byteCount = samples.count * MemoryLayout<Float>.size
      samples.withUnsafeMutableBytes { destination in
        destination.copyMemory(
          from: UnsafeRawBufferPointer(
            start: channelData[0],
            count: byteCount
          )
        )
      }
    } else {
      for frameIndex in 0..<frameCount {
        for channelIndex in 0..<channelCount {
          samples[(frameIndex * channelCount) + channelIndex] =
            channelData[channelIndex][frameIndex]
        }
      }
    }

    return samples.withUnsafeBytes { Data($0) }
  }

  static func decode(_ frame: VoiceAudioFrame) throws -> AVAudioPCMBuffer? {
    guard frame.format ?? formatName == formatName,
      let audio = frame.audio,
      let sampleRate = frame.sampleRate,
      let channelCount = frame.channels,
      sampleRate > 0,
      channelCount > 0
    else {
      return nil
    }

    let bytesPerFrame = channelCount * MemoryLayout<Float>.size
    guard audio.count % bytesPerFrame == 0 else {
      throw PCMFloat32CodecError.invalidOutputPayload(
        byteCount: audio.count,
        channels: channelCount
      )
    }

    guard let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: Double(sampleRate),
      channels: AVAudioChannelCount(channelCount),
      interleaved: true
    ) else {
      throw PCMFloat32CodecError.invalidOutputMetadata
    }

    let frameCount = AVAudioFrameCount(audio.count / bytesPerFrame)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
      throw PCMFloat32CodecError.outputBufferAllocationFailed
    }

    buffer.frameLength = frameCount
    guard let channelData = buffer.floatChannelData else {
      throw PCMFloat32CodecError.missingChannelData
    }

    audio.withUnsafeBytes { source in
      UnsafeMutableRawBufferPointer(start: channelData[0], count: audio.count)
        .copyMemory(from: source)
    }

    return buffer
  }
}
