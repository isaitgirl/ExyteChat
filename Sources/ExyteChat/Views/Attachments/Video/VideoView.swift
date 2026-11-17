//
//  Created by Alex.M on 21.06.2022.
//

import SwiftUI
import AVKit

struct VideoView: View {

    @EnvironmentObject var mediaPagesViewModel: FullscreenMediaPagesViewModel
    @Environment(\.chatTheme) private var theme

    @StateObject var viewModel: VideoViewModel

    var body: some View {
        Group {
            if let player = viewModel.player, viewModel.status == .readyToPlay {
                content(for: player)
            } else {
                ActivityIndicator()
            }
        }
        .contentShape(Rectangle())
        .onAppear {
            viewModel.onStart()

            mediaPagesViewModel.toggleVideoPlaying = {
                viewModel.togglePlay()
            }
            mediaPagesViewModel.toggleVideoMuted = {
                viewModel.toggleMute()
            }
        }
        .onDisappear {
            viewModel.onStop()
        }
        .onChange(of: viewModel.isPlaying) { _ , newValue in
            mediaPagesViewModel.videoPlaying = newValue
        }
        .onChange(of: viewModel.isMuted) {  _ , newValue in
            mediaPagesViewModel.videoMuted = newValue
        }
    }

    func content(for player: AVPlayer) -> some View {
        // isaCloud: play starts only when the picture is ready to show, so the sound never begins over a gray frame
        PlayerControllerView(player: player) {
            viewModel.autoPlayIfNeeded()
        }
        .onAppear {
            // isaCloud: fallback for files without picture (audio only), which never report ready for display
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                viewModel.autoPlayIfNeeded()
            }
        }
    }
}

/// isaCloud: AVPlayerViewController instead of SwiftUI's VideoPlayer, so we know when the picture is ready (isReadyForDisplay)
private struct PlayerControllerView: UIViewControllerRepresentable {
    let player: AVPlayer
    let onReadyForDisplay: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReadyForDisplay: onReadyForDisplay)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.videoGravity = .resizeAspect
        controller.showsPlaybackControls = true
        context.coordinator.observe(controller)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }

    final class Coordinator {
        private let onReadyForDisplay: () -> Void
        private var observation: NSKeyValueObservation?
        private var notified = false

        init(onReadyForDisplay: @escaping () -> Void) {
            self.onReadyForDisplay = onReadyForDisplay
        }

        func observe(_ controller: AVPlayerViewController) {
            observation = controller.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] controller, _ in
                guard controller.isReadyForDisplay, let self, !self.notified else { return }
                self.notified = true
                DispatchQueue.main.async {
                    self.onReadyForDisplay()
                }
            }
        }
    }
}
