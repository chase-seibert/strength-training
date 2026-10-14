import MetalKit
import SwiftUI

/// A finite, decorative burst. The summary owns its lifetime; the GPU owns particle motion.
struct WorkoutConfettiView: UIViewRepresentable {
  let isActive: Bool

  func makeCoordinator() -> Renderer? {
    Renderer(device: MTLCreateSystemDefaultDevice())
  }

  func makeUIView(context: Context) -> MTKView {
    let view = MTKView(frame: .zero, device: context.coordinator?.device)
    view.backgroundColor = .clear
    view.isOpaque = false
    view.clearColor = MTLClearColorMake(0, 0, 0, 0)
    view.colorPixelFormat = .bgra8Unorm
    view.preferredFramesPerSecond = 30
    view.isUserInteractionEnabled = false
    view.isAccessibilityElement = false
    view.delegate = context.coordinator
    view.isPaused = !isActive || context.coordinator == nil
    return view
  }

  func updateUIView(_ view: MTKView, context: Context) {
    view.isPaused = !isActive || context.coordinator == nil
  }

  static func dismantleUIView(_ view: MTKView, coordinator: Renderer?) {
    view.isPaused = true
    view.delegate = nil
    view.releaseDrawables()
  }

  final class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private var startedAt: TimeInterval?

    init?(device: MTLDevice?) {
      guard let device,
        let queue = device.makeCommandQueue(),
        let library = device.makeDefaultLibrary(),
        let vertex = library.makeFunction(name: "workoutConfettiVertex"),
        let fragment = library.makeFunction(name: "workoutConfettiFragment")
      else { return nil }
      let descriptor = MTLRenderPipelineDescriptor()
      descriptor.vertexFunction = vertex
      descriptor.fragmentFunction = fragment
      let color = descriptor.colorAttachments[0]!
      color.pixelFormat = .bgra8Unorm
      color.isBlendingEnabled = true
      // The shader returns premultiplied alpha for correct compositing over SwiftUI.
      color.sourceRGBBlendFactor = .one
      color.destinationRGBBlendFactor = .oneMinusSourceAlpha
      color.sourceAlphaBlendFactor = .one
      color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
      guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else {
        return nil
      }
      self.device = device
      self.queue = queue
      self.pipeline = pipeline
      super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
      guard view.bounds.width > 0, view.bounds.height > 0,
        let pass = view.currentRenderPassDescriptor,
        let drawable = view.currentDrawable,
        let command = queue.makeCommandBuffer(),
        let encoder = command.makeRenderCommandEncoder(descriptor: pass)
      else { return }
      let now = ProcessInfo.processInfo.systemUptime
      if startedAt == nil { startedAt = now }
      var elapsed = Float(now - (startedAt ?? now))
      #if DEBUG
        // Reproducible visual evidence without changing the finite production lifetime.
        if ProcessInfo.processInfo.arguments.contains("-confettiSnapshotFixture") {
          elapsed = 1.4
        }
      #endif
      var uniforms = SIMD4<Float>(
        Float(view.bounds.width), Float(view.bounds.height), elapsed, 0)
      encoder.setRenderPipelineState(pipeline)
      encoder.setVertexBytes(&uniforms, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
      encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: 220)
      encoder.endEncoding()
      command.present(drawable)
      command.commit()
      if elapsed >= 5 { view.isPaused = true }
    }
  }
}
