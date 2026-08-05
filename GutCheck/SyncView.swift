import SwiftUI
import CloudKit
import UIKit

/// Household sync: status plus the invite. One sheet, no settings maze.
struct SyncSheet: View {
    @EnvironmentObject var store: AppStore
    @ObservedObject var sync = CloudSync.shared
    @Environment(\.dismiss) private var dismiss
    @State private var share: CKShare?
    @State private var showShareController = false
    @State private var shareError: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: statusSymbol)
                        .font(.title2)
                        .foregroundColor(statusColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sync.status.label)
                            .font(.headline)
                        if let lastSync = sync.lastSync {
                            Text("Last synced \(relativeDay(lastSync))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .card()

                if case .live(let isOwner) = sync.status {
                    if isOwner {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Share with your household")
                                .font(.subheadline.weight(.semibold))
                            Text("Everyone you invite sees the same animals and logs the same record, from their own phone.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button {
                                prepareShare()
                            } label: {
                                Label("Invite someone", systemImage: "person.badge.plus")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .card()
                    } else {
                        Text("You're logging into a shared household. Everything you add shows up on everyone's phone.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .card()
                    }
                } else if case .off = sync.status {
                    Text("Once iCloud is available, the household syncs on its own and you can invite someone to share it. Until then everything stays on this phone.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .card()
                }

                if let shareError {
                    Text(shareError)
                        .font(.caption)
                        .foregroundColor(Tier.concern.color)
                }

                Spacer()

                Text("Synced through iCloud. Photos and logs stay in your household's iCloud, not on our servers. There are no servers.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Household sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareController) {
                if let share {
                    CloudShareView(share: share, container: sync.container)
                        .ignoresSafeArea()
                }
            }
        }
    }

    private var statusSymbol: String {
        switch sync.status {
        case .off: return "icloud.slash"
        case .starting: return "arrow.triangle.2.circlepath.icloud"
        case .live: return "checkmark.icloud.fill"
        }
    }

    private var statusColor: Color {
        switch sync.status {
        case .off: return .secondary
        case .starting: return .secondary
        case .live: return Tier.normal.color
        }
    }

    private func prepareShare() {
        shareError = nil
        Task {
            do {
                share = try await CloudSync.shared.fetchOrCreateShare()
                showShareController = true
            } catch {
                shareError = "Couldn't start sharing: \(error.localizedDescription)"
            }
        }
    }
}

/// The system share sheet for a CKShare: add people, copy the link, manage
/// participants. Apple's UI, wrapped.
struct CloudShareView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for csc: UICloudSharingController) -> String? { "Scoop household" }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {}
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {}
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {}
    }
}
