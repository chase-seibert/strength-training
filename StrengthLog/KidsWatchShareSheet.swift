import CloudKit
import SwiftUI
import UIKit

struct KidsWatchShareSheet: UIViewControllerRepresentable {
  let share: CKShare

  func makeUIViewController(context: Context) -> UICloudSharingController {
    let controller = UICloudSharingController(
      share: share, container: KidsWatchCloudStore.container)
    controller.availablePermissions = [.allowPrivate, .allowReadOnly]
    return controller
  }

  func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}
}
