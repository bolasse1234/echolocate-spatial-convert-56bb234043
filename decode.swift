// Decode a >=4-channel audio track using Apple's native decoder on macOS.
// Does not upload media or assume that the four output channels are microphones.
import AVFoundation
import CoreMedia

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: swift decode.swift input.mov spatial.caf")
}
let asset = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
let tracks = asset.tracks(withMediaType: .audio)
guard let track = tracks.first(where: { t in
    t.formatDescriptions.contains { value in
        let description = value as! CMFormatDescription
        return (CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee.mChannelsPerFrame ?? 0) >= 4
    }
}) else { fatalError("No audio track with four or more channels") }

let reader = try AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
    AVFormatIDKey: kAudioFormatLinearPCM,
    AVLinearPCMBitDepthKey: 32,
    AVLinearPCMIsFloatKey: true,
    AVLinearPCMIsNonInterleaved: false,
])
guard reader.canAdd(output) else { fatalError("Cannot add PCM decoder output") }
reader.add(output)
guard reader.startReading() else { fatalError("Cannot start: \(String(describing: reader.error))") }
var file: AVAudioFile? = nil
var frames: Int64 = 0
while let sample = output.copyNextSampleBuffer() {
    let count = CMSampleBufferGetNumSamples(sample)
    guard count > 0, let description = CMSampleBufferGetFormatDescription(sample) else { continue }
    let format = AVAudioFormat(cmAudioFormatDescription: description)
    guard format.channelCount >= 4 else { fatalError("Decoder returned fewer than four channels") }
    if file == nil {
        print("Decoded sample rate: \(format.sampleRate), channels: \(format.channelCount)")
        print("Decoded channel layout: \(String(describing: format.channelLayout))")
        file = try AVAudioFile(forWriting: URL(fileURLWithPath: CommandLine.arguments[2]),
            settings: format.settings, commonFormat: format.commonFormat,
            interleaved: format.isInterleaved)
    }
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else {
        fatalError("Cannot allocate PCM buffer")
    }
    buffer.frameLength = AVAudioFrameCount(count)
    try CMSampleBufferCopyPCMDataIntoAudioBufferList(sample, at: 0, frameCount: Int32(count),
                                                   into: buffer.mutableAudioBufferList)
    try file!.write(from: buffer)
    frames += Int64(count)
}
guard reader.status == .completed && frames > 0 else {
    fatalError("Incomplete decode: \(String(describing: reader.error)), frames: \(frames)")
}
print("Wrote \(frames) decoded frames")
