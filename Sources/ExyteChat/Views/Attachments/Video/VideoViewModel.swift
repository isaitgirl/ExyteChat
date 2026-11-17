//
//  Created by Alex.M on 21.06.2022.
//

import Foundation
import Combine
import AVKit

// TODO: Create option "download video before playing"
final class VideoViewModel: ObservableObject {

    @Published var attachment: Attachment
    @Published var player: AVPlayer?

    @Published var isPlaying = false
    @Published var isMuted = false

    private var subscriptions = Set<AnyCancellable>()
    @Published var status: AVPlayer.Status = .unknown
    // isaCloud: autoplay happens once, and never after the user already played or paused the video by hand
    private var didAutoPlay = false

    init(attachment: Attachment) {
        self.attachment = attachment
    }

    func onStart() {
        if player == nil {
            let videoAsset = AVURLAsset(url: attachment.full, options: attachment.mimeType != nil ? [AVURLAssetOverrideMIMETypeKey: attachment.mimeType] : [:])
            let playerItem = AVPlayerItem(asset: videoAsset)
            self.player = AVPlayer(playerItem: playerItem)
            self.player?.publisher(for: \.status)
                .receive(on: DispatchQueue.main)
                .assign(to: &$status)

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.finishVideo()
            }
        }
    }

    func onStop() {
        pauseVideo()
    }

    func togglePlay() {
        didAutoPlay = true
        if player?.isPlaying == true {
            pauseVideo()
        } else {
            playVideo()
        }
    }

    func toggleMute() {
        player?.isMuted.toggle()
        isMuted = player?.isMuted ?? false
    }

    // isaCloud: called once the picture is on screen (or by a fallback timer), so the sound never starts over a gray frame
    func autoPlayIfNeeded() {
        guard !didAutoPlay else { return }
        didAutoPlay = true
        diagLog("isaCloud-VIDEO autoplay")
        playVideo()
    }

    func playVideo() {
        player?.play()
        isPlaying = player?.isPlaying ?? false
    }

    func pauseVideo() {
        player?.pause()
        isPlaying = player?.isPlaying ?? false
    }

    func finishVideo() {
        player?.seek(to: CMTime(seconds: 0, preferredTimescale: 10))
        isPlaying = false
    }
}

// isaCloud: DIAG video-cinza (temporary) - writes to Library/Caches/isacloud-video.log so devicectl can read it
func diagLog(_ format: String, _ args: CVarArg...) {
    let line = String(format: format, arguments: args)
    NSLog("%@", line)
    guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
    let url = dir.appendingPathComponent("isacloud-video.log")
    let stamp = ISO8601DateFormatter().string(from: Date())
    let data = Data("\(stamp) \(line)\n".utf8)
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile(); handle.write(data); try? handle.close()
    } else {
        try? data.write(to: url)
    }
}
