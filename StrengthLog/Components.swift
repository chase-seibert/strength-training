import SwiftUI
import UIKit

enum NumericAdjustmentDirection {
  case decrease
  case increase
}

enum NumericAdjustmentPolicy {
  case additive(step: Double)
  case standardWeight(interval: Double)

  static func forWeight(unit: TrackingUnit) -> NumericAdjustmentPolicy? {
    switch unit {
    case .pounds: .standardWeight(interval: 5)
    case .kilograms: .standardWeight(interval: 2.5)
    default: nil
    }
  }

  func adjusted(_ value: Double, direction: NumericAdjustmentDirection, minimum: Double) -> Double?
  {
    guard value.isFinite, minimum.isFinite else { return nil }
    let adjusted: Double
    switch self {
    case .additive(let step):
      guard step.isFinite, step > 0 else { return nil }
      switch direction {
      case .increase: adjusted = value + step
      case .decrease: adjusted = value - step
      }
    case .standardWeight(let interval):
      guard interval.isFinite, interval > 0 else { return nil }
      let position = value / interval
      guard position.isFinite else { return nil }
      let nearest = position.rounded()
      let onBoundary = abs(position - nearest) <= 1e-9
      let next: Double
      switch direction {
      case .increase: next = (onBoundary ? nearest : floor(position)) + 1
      case .decrease: next = (onBoundary ? nearest : ceil(position)) - 1
      }
      adjusted = next * interval
    }
    guard adjusted.isFinite else { return nil }
    let clamped = max(minimum, adjusted)
    return (clamped * 1_000_000_000).rounded() / 1_000_000_000
  }
}

func numericText(_ value: Double) -> String {
  guard value.isFinite else { return "" }
  if value.rounded() == value, value >= Double(Int.min), value < Double(Int.max) {
    return String(Int(value))
  }
  return String(value)
}

func exerciseCountText(_ count: Int) -> String {
  "\(count) \(count == 1 ? "exercise" : "exercises")"
}

struct SectionEyebrow: View {
  let text: String

  var body: some View {
    Text(text.uppercased())
      .font(.caption.weight(.bold))
      .tracking(1.2)
      .foregroundStyle(.secondary)
  }
}

struct InitialBadge: View {
  let name: String
  let colorHex: String
  var size: CGFloat = 30

  var body: some View {
    Text(String(name.prefix(1)).uppercased())
      .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
      .foregroundStyle(.white)
      .frame(width: size, height: size)
      .background(Color(hex: colorHex), in: Circle())
      .accessibilityLabel(name)
  }
}

struct SelectAllTextField: UIViewRepresentable {
  @Binding var text: String
  @Binding var isFocused: Bool
  let keyboardType: UIKeyboardType
  let textAlignment: NSTextAlignment
  let font: UIFont
  let accessibilityLabel: String
  let adjustmentPolicy: NumericAdjustmentPolicy
  let minimumValue: Double
  var onCommit: (String) -> Void = { _ in }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIView(context: Context) -> UITextField {
    let textField = UITextField()
    textField.delegate = context.coordinator
    textField.keyboardType = keyboardType
    textField.textAlignment = textAlignment
    textField.font = font
    textField.accessibilityLabel = accessibilityLabel
    textField.inputAccessoryView = KeyboardAccessoryToolbar(
      textField: textField,
      adjustmentPolicy: adjustmentPolicy,
      minimumValue: minimumValue,
      onCommit: onCommit)
    textField.addTarget(
      context.coordinator, action: #selector(Coordinator.textDidChange(_:)),
      for: .editingChanged)
    return textField
  }

  func updateUIView(_ textField: UITextField, context: Context) {
    context.coordinator.update(self)
    textField.accessibilityLabel = accessibilityLabel
    textField.keyboardType = keyboardType
    if let toolbar = textField.inputAccessoryView as? KeyboardAccessoryToolbar {
      toolbar.update(
        adjustmentPolicy: adjustmentPolicy,
        minimumValue: minimumValue,
        onCommit: onCommit)
    }
    if textField.text != text {
      textField.text = text
    }

    if isFocused, !textField.isFirstResponder {
      textField.becomeFirstResponder()
    } else if !isFocused, textField.isFirstResponder {
      textField.resignFirstResponder()
    }
  }

  final class Coordinator: NSObject, UITextFieldDelegate {
    private var parent: SelectAllTextField
    private weak var textField: UITextField?
    private var keyboardObserver: NSObjectProtocol?

    init(_ parent: SelectAllTextField) {
      self.parent = parent
      super.init()
      keyboardObserver = NotificationCenter.default.addObserver(
        forName: UIResponder.keyboardWillChangeFrameNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        guard let self, let textField = self.textField, textField.isFirstResponder else { return }
        self.reveal(textField, animated: true)
      }
    }

    deinit {
      if let keyboardObserver {
        NotificationCenter.default.removeObserver(keyboardObserver)
      }
    }

    func update(_ parent: SelectAllTextField) {
      self.parent = parent
    }

    @objc func textDidChange(_ textField: UITextField) {
      parent.text = textField.text ?? ""
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
      self.textField = textField
      parent.isFocused = true
      DispatchQueue.main.async {
        textField.selectAll(nil)
        self.reveal(textField, animated: false)
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak textField] in
        guard let self, let textField, textField.isFirstResponder else { return }
        self.reveal(textField, animated: true)
      }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
      parent.onCommit(textField.text ?? "")
      parent.isFocused = false
    }

    private func reveal(_ textField: UITextField, animated: Bool) {
      var ancestor = textField.superview
      while let view = ancestor {
        if let scrollView = view as? UIScrollView {
          let rect = textField.convert(
            textField.bounds.insetBy(dx: 0, dy: -24), to: scrollView)
          scrollView.scrollRectToVisible(rect, animated: animated)
        }
        ancestor = view.superview
      }
    }
  }
}

private final class KeyboardAccessoryToolbar: UIToolbar {
  private weak var textField: UITextField?
  private var adjustmentPolicy: NumericAdjustmentPolicy
  private var minimumValue: Double
  private var onCommit: (String) -> Void

  init(
    textField: UITextField,
    adjustmentPolicy: NumericAdjustmentPolicy,
    minimumValue: Double,
    onCommit: @escaping (String) -> Void
  ) {
    self.textField = textField
    self.adjustmentPolicy = adjustmentPolicy
    self.minimumValue = minimumValue
    self.onCommit = onCommit
    super.init(frame: .zero)

    let decrease = UIBarButtonItem(
      image: UIImage(systemName: "minus"),
      style: .plain,
      target: self,
      action: #selector(decreaseValue)
    )
    decrease.accessibilityLabel = "Decrease value"

    let increase = UIBarButtonItem(
      image: UIImage(systemName: "plus"),
      style: .plain,
      target: self,
      action: #selector(increaseValue)
    )
    increase.accessibilityLabel = "Increase value"

    let hideKeyboard = UIBarButtonItem(
      image: UIImage(systemName: "keyboard.chevron.compact.down"),
      style: .plain,
      target: self,
      action: #selector(hideKeyboard)
    )
    hideKeyboard.accessibilityLabel = "Hide keyboard"
    items = [
      decrease,
      increase,
      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
      hideKeyboard,
    ]
    sizeToFit()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func update(
    adjustmentPolicy: NumericAdjustmentPolicy,
    minimumValue: Double,
    onCommit: @escaping (String) -> Void
  ) {
    self.adjustmentPolicy = adjustmentPolicy
    self.minimumValue = minimumValue
    self.onCommit = onCommit
  }

  @objc private func hideKeyboard() {
    textField?.resignFirstResponder()
  }

  @objc private func decreaseValue() {
    adjustValue(direction: .decrease)
  }

  @objc private func increaseValue() {
    adjustValue(direction: .increase)
  }

  private func adjustValue(direction: NumericAdjustmentDirection) {
    guard let textField, let value = Double(textField.text ?? "") else { return }
    guard
      let adjustedValue = adjustmentPolicy.adjusted(
        value, direction: direction, minimum: minimumValue)
    else { return }
    textField.text = numericText(adjustedValue)
    textField.sendActions(for: .editingChanged)
    onCommit(textField.text ?? "")
  }
}

struct DismissKeyboardOnTap: UIViewRepresentable {
  func makeUIView(context: Context) -> DismissKeyboardView {
    DismissKeyboardView()
  }

  func updateUIView(_ view: DismissKeyboardView, context: Context) {}
}

final class DismissKeyboardView: UIView, UIGestureRecognizerDelegate {
  private weak var attachedWindow: UIWindow?
  private lazy var tapGesture: UITapGestureRecognizer = {
    let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    gesture.cancelsTouchesInView = false
    gesture.delegate = self
    return gesture
  }()

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if let window {
      guard attachedWindow !== window else { return }
      attachedWindow?.removeGestureRecognizer(tapGesture)
      attachedWindow = window
      window.addGestureRecognizer(tapGesture)
    } else if let attachedWindow {
      attachedWindow.removeGestureRecognizer(tapGesture)
      self.attachedWindow = nil
    }
  }

  @objc private func handleTap() {
    attachedWindow?.endEditing(true)
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch
  ) -> Bool {
    guard let firstResponder = attachedWindow?.rootViewController?.view.currentFirstResponder,
      let touchedView = touch.view
    else {
      return true
    }

    // SwiftUI can put private wrapper views between the touch target and the
    // UIKit text field. Ignore the field and its descendants, but not an
    // ancestor such as the enclosing List or card.
    return firstResponder !== touchedView
      && !touchedView.isDescendant(of: firstResponder)
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    true
  }

  deinit {
    attachedWindow?.removeGestureRecognizer(tapGesture)
  }
}

extension UIView {
  fileprivate var currentFirstResponder: UIView? {
    if isFirstResponder { return self }

    for subview in subviews {
      if let responder = subview.currentFirstResponder {
        return responder
      }
    }

    return nil
  }
}

struct MetricTile: View {
  let value: String
  let label: String
  let symbol: String
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: symbol)
        .foregroundStyle(tint)
        .font(.title3.weight(.semibold))
      Text(value)
        .font(.title2.bold())
        .contentTransition(.numericText())
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

struct EmptyStateView: View {
  let symbol: String
  let title: String
  let message: String

  var body: some View {
    ContentUnavailableView(title, systemImage: symbol, description: Text(message))
  }
}

struct ExerciseArtwork: View {
  let exercise: Exercise

  var body: some View {
    ExerciseRemoteImage(url: exercise.imageURL)
  }
}

private final class ExerciseImageCache: @unchecked Sendable {
  static let shared = ExerciseImageCache()

  let images: NSCache<NSURL, UIImage> = {
    let cache = NSCache<NSURL, UIImage>()
    cache.totalCostLimit = 64 * 1_024 * 1_024
    return cache
  }()
}

struct ExerciseRemoteImage: View {
  let url: URL?
  @State private var image: UIImage?

  var body: some View {
    Group {
      if let image {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        exerciseImagePlaceholder
      }
    }
    .clipped()
    .task(id: url) {
      image = nil
      guard let url, url.isFileURL else { return }
      let key = url as NSURL
      if let cached = ExerciseImageCache.shared.images.object(forKey: key) {
        image = cached
        return
      }

      let loadedImage = await Task.detached(priority: .userInitiated) { () -> UIImage? in
        autoreleasepool {
          guard let source = UIImage(contentsOfFile: url.path) else { return nil }
          return source.preparingForDisplay() ?? source
        }
      }.value
      guard !Task.isCancelled, let loadedImage else { return }
      let cost = loadedImage.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
      ExerciseImageCache.shared.images.setObject(loadedImage, forKey: key, cost: cost)
      image = loadedImage
    }
  }

  private var exerciseImagePlaceholder: some View {
    ZStack {
      LinearGradient(
        colors: [Theme.navy, Theme.navy.opacity(0.72)], startPoint: .topLeading,
        endPoint: .bottomTrailing)
      Image(systemName: "figure.strengthtraining.traditional")
        .font(.system(size: 34, weight: .semibold))
        .foregroundStyle(Theme.coral)
    }
  }
}

struct ExerciseImageCarousel: View {
  let exercise: Exercise
  var height: CGFloat = 300
  @State private var selection = 0

  var body: some View {
    ZStack(alignment: .topTrailing) {
      if exercise.imageURLs.isEmpty {
        ExerciseRemoteImage(url: nil)
      } else {
        TabView(selection: $selection) {
          ForEach(Array(exercise.imageURLs.enumerated()), id: \.offset) { index, url in
            ExerciseRemoteImage(url: url)
              .tag(index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: exercise.imageURLs.count > 1 ? .always : .never))
      }

      if exercise.imageURLs.count > 1 {
        Text("\(selection + 1) / \(exercise.imageURLs.count)")
          .font(.caption.bold().monospacedDigit())
          .foregroundStyle(.white)
          .padding(.horizontal, 9)
          .padding(.vertical, 6)
          .background(.black.opacity(0.58), in: Capsule())
          .padding(12)
      }
    }
    .frame(height: height)
    .background(Color.secondary.opacity(0.08))
    .clipped()
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Form images for \(exercise.name)")
  }
}

struct ExerciseImageSheet: View {
  @Environment(\.dismiss) private var dismiss
  let exercise: Exercise

  var body: some View {
    NavigationStack {
      VStack(spacing: 18) {
        ExerciseImageCarousel(exercise: exercise, height: 460)
          .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        Text("Swipe to compare positions")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding()
      .background(Color(.systemGroupedBackground))
      .navigationTitle(exercise.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
      }
    }
  }
}

extension Date {
  var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}
