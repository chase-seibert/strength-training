import SwiftUI
import UIKit

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
  let step: Double
  let minimumValue: Double

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
      textField: textField, step: step, minimumValue: minimumValue)
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
      toolbar.update(step: step, minimumValue: minimumValue)
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
  private var step: Double
  private var minimumValue: Double

  init(textField: UITextField, step: Double, minimumValue: Double) {
    self.textField = textField
    self.step = step
    self.minimumValue = minimumValue
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

  func update(step: Double, minimumValue: Double) {
    self.step = step
    self.minimumValue = minimumValue
  }

  @objc private func hideKeyboard() {
    textField?.resignFirstResponder()
  }

  @objc private func decreaseValue() {
    adjustValue(by: -step)
  }

  @objc private func increaseValue() {
    adjustValue(by: step)
  }

  private func adjustValue(by delta: Double) {
    guard let textField, let value = Double(textField.text ?? "") else { return }
    let adjustedValue = max(minimumValue, value + delta)
    textField.text =
      adjustedValue.rounded() == adjustedValue
      ? String(Int(adjustedValue))
      : String(adjustedValue)
    textField.sendActions(for: .editingChanged)
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
