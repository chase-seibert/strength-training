import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Analyze simulator video using the opt-in binary clock and the completion badge regions.
// A visible change requires mean RGB difference >=12/255 and >=8% changed pixels (>30/255).
// This measures first recognizable badge pixels, quantized to recorded frames.
let videoURL = URL(fileURLWithPath: CommandLine.arguments[1])
let samplesURL = URL(fileURLWithPath: CommandLine.arguments[2])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[3])
let lines = try String(contentsOf: samplesURL, encoding: .utf8).split(separator: "\n")
let samples = try lines.map { try JSONSerialization.jsonObject(with: Data($0.utf8)) as! [String: Any] }
let actions = samples.filter { $0["type"] as? String == "completion" && $0["completing"] as? Bool == true }
var byKey: [String: [String: Any]] = [:]
for action in actions {
  let key = "\(action["launch_token"]!)|\(action["sequence"]!)"
  byKey[key] = action
}
let asset = AVURLAsset(url: videoURL)
let semaphore = DispatchSemaphore(value: 0)
var track: AVAssetTrack?
Task {
  defer { semaphore.signal() }
  do { track = try await asset.loadTracks(withMediaType: .video).first }
  catch { fputs("Cannot load video tracks: \(error)\n", stderr) }
}
semaphore.wait()
guard let track else { fatalError("Video contains no video track") }
let reader = try AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track,
  outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(output)
guard reader.startReading() else { fatalError("Cannot start reading video") }
var previous: [UInt8] = []
var baselines: [String: [[UInt8]]] = [:]
var results: [String: [String: Any]] = [:]
var previousPTS: Double?
var frameGaps: [Double] = []

func pixel(_ bytes: [UInt8], _ x: Int, _ y: Int, _ stride: Int, _ width: Int, _ height: Int) -> [UInt8] {
  guard x >= 0, y >= 0, x < width, y < height else { return [0, 0, 0] }
  let offset = y * stride + x * 4
  return Array(bytes[offset..<(offset + 3)])
}

func region(_ bytes: [UInt8], _ rect: [Double], _ scale: Double, _ stride: Int, _ width: Int, _ height: Int) -> [UInt8] {
  var result: [UInt8] = []
  // Checkmark circle is at the top trailing corner, away from the number label.
  for y in Int((rect[1] - 4) * scale)..<Int((rect[1] + 12) * scale) {
    for x in Int((rect[0] + rect[2] - 13) * scale)..<Int((rect[0] + rect[2] + 3) * scale) {
      result += pixel(bytes, x, y, stride, width, height)
    }
  }
  return result
}

func changed(_ before: [UInt8], _ after: [UInt8]) -> Bool {
  guard before.count == after.count, !before.isEmpty else { return false }
  let differences = zip(before, after).map { abs(Int($0) - Int($1)) }
  let mean = Double(differences.reduce(0, +)) / Double(differences.count)
  let changedFraction = Double(differences.filter { $0 > 30 }.count) / Double(differences.count)
  return mean >= 12 && changedFraction >= 0.08
}

while let sample = output.copyNextSampleBuffer() {
  guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
  let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
  if let previousPTS { frameGaps.append(pts - previousPTS) }
  previousPTS = pts
  CVPixelBufferLockBaseAddress(buffer, .readOnly)
  let width = CVPixelBufferGetWidth(buffer)
  let height = CVPixelBufferGetHeight(buffer)
  let stride = CVPixelBufferGetBytesPerRow(buffer)
  let bytes = Array(UnsafeBufferPointer(start: CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self), count: stride * height))
  CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
  for location in actions.prefix(3) {
    guard let optical = location["optical_rect"] as? [Double],
      let windowSize = location["window_size"] as? [Double] else { continue }
    let scale = Double(width) / windowSize[0]
    var words: [UInt32] = []
    for row in 0..<5 {
      var word: UInt32 = 0
      for column in 0..<32 {
        let x = Int((optical[0] + Double(column * 8 + 4)) * scale)
        let y = Int((optical[1] + Double(row * 6 + 3)) * scale)
        let color = pixel(bytes, x, y, stride, width, height)
        word = (word << 1) | (color.map(Int.init).reduce(0, +) > 384 ? 1 : 0)
      }
      words.append(word)
    }
    guard words[0] == 0xA55A5AA5 else { continue }
    let key = "\(words[1])|\(words[2])"
    guard let action = byKey[key], results[key] == nil,
      let rects = action["target_rects"] as? [String: [Double]], !rects.isEmpty,
      !previous.isEmpty else { continue }
    let orderedRects = rects.keys.sorted().compactMap { rects[$0] }
    if baselines[key] == nil {
      baselines[key] = orderedRects.map { region(previous, $0, scale, stride, width, height) }
    }
    let current = orderedRects.map { region(bytes, $0, scale, stride, width, height) }
    if zip(baselines[key]!, current).allSatisfy({ changed($0, $1) }), words[4] >= words[3] {
      results[key] = ["launch_token": words[1], "sequence": words[2],
        "kind": action["kind"]!, "scenario": action["scenario"]!,
        "pixel_visual_latency_ms": words[4] - words[3],
        "video_pts_s": pts, "target_count": rects.count,
        "source": "simulator-video-optical-clock", "frame_quantization_ms": 1000.0 / 60]
      // Save proof frames beside the video, never in workout data.
      let data = Data(bytes) as CFData
      if let provider = CGDataProvider(data: data),
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
          bytesPerRow: stride, space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
          provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
        let destination = CGImageDestinationCreateWithURL(outputURL.deletingLastPathComponent()
          .appendingPathComponent("visible-\(key.replacingOccurrences(of: "|", with: "-" )).png") as CFURL,
          UTType.png.identifier as CFString, 1, nil) {
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
      }
    }
    break
  }
  previous = bytes
}
let payload: [String: Any] = ["visual_samples": Array(results.values),
  "video_frame_count": frameGaps.count + 1, "video_worst_gap_ms": (frameGaps.max() ?? 0) * 1000,
  "video_gap_warning": "Recording gaps are capture gaps and are not app animation hitches."]
try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]).write(to: outputURL)
