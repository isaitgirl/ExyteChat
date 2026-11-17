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
                NSLog("isaCloud-VIDEO fallback fired")
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
        // isaCloud: DIAG video-cinza (temporary) - the Live Text analysis of video frames is turned off as a test
        controller.allowsVideoFrameAnalysis = false
        NSLog("isaCloud-VIDEO make")
        context.coordinator.observe(controller)
        context.coordinator.dump("make", controller)
        for delay in [0.3, 1.0, 2.0, 4.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak controller] in
                if let controller { context.coordinator.dump("t+\(delay)", controller) }
            }
        }
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.dump("update", controller)
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

        // isaCloud: DIAG video-cinza (temporary)
        func dump(_ tag: String, _ c: AVPlayerViewController) {
            let item = c.player?.currentItem
            NSLog("isaCloud-VIDEO %@ ready=%d window=%d frame=%@ videoBounds=%@ itemStatus=%ld size=%@ rate=%.1f tcs=%ld t=%.2f alpha=%.1f hidden=%d",
                  tag, c.isReadyForDisplay ? 1 : 0, c.view.window != nil ? 1 : 0,
                  NSCoder.string(for: c.view.frame), NSCoder.string(for: c.videoBounds),
                  item?.status.rawValue ?? -1, item.map { NSCoder.string(for: $0.presentationSize) } ?? "-",
                  c.player?.rate ?? -1, c.player?.timeControlStatus.rawValue ?? -1, c.player?.currentTime().seconds ?? -1,
                  c.view.alpha, c.view.isHidden ? 1 : 0)
        }

        func observe(_ controller: AVPlayerViewController) {
            observation = controller.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] controller, _ in
                NSLog("isaCloud-VIDEO isReadyForDisplay -> %d", controller.isReadyForDisplay ? 1 : 0)
                guard controller.isReadyForDisplay, let self, !self.notified else { return }
                self.notified = true
                DispatchQueue.main.async {
                    self.onReadyForDisplay()
                }
            }
        }
    }
}
