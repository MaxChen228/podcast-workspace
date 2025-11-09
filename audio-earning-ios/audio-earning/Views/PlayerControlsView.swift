//
//  PlayerControlsView.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import SwiftUI

/// Playback controls view.
struct PlayerControlsView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Progress bar
            ProgressSlider(
                currentTime: viewModel.currentTime,
                totalDuration: viewModel.totalDuration,
                onSeek: { time in
                    viewModel.seek(to: time)
                }
            )
            .padding(.horizontal)

            timeInfoBar
                .padding(.horizontal)

            // Playback buttons
            HStack(spacing: 30) {
                // Skip backward 15 seconds
                Button(action: {
                    viewModel.skip(seconds: -15)
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }

                // Play / Pause
                Button(action: {
                    viewModel.togglePlayPause()
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                }

                // Skip forward 15 seconds
                Button(action: {
                    viewModel.skip(seconds: 15)
                }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var isPlaying: Bool {
        viewModel.playerState == .playing
    }

    private var timeInfoBar: some View {
        HStack {
            Text(formatTime(viewModel.currentTime))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            Spacer()

            Text(formatTime(viewModel.totalDuration))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Progress slider control.
struct ProgressSlider: View {
    let currentTime: TimeInterval
    let totalDuration: TimeInterval
    let onSeek: (TimeInterval) -> Void

    @State private var isDragging = false
    @State private var tempValue: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                    .cornerRadius(2)

                // Played progress
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: progressWidth(in: geometry.size.width), height: 4)
                    .cornerRadius(2)

                // Draggable handle
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 16, height: 16)
                    .offset(x: progressWidth(in: geometry.size.width) - 8)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                isDragging = true
                                let x = max(0, min(gesture.location.x, geometry.size.width))
                                tempValue = Double(x / geometry.size.width) * totalDuration
                            }
                            .onEnded { _ in
                                isDragging = false
                                onSeek(tempValue)
                            }
                    )
            }
        }
        .frame(height: 20)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let progress = isDragging ? tempValue : currentTime
        guard totalDuration > 0 else { return 0 }
        return CGFloat(progress / totalDuration) * totalWidth
    }
}

#Preview {
    VStack {
        // Create a demo view model
        let viewModel = AudioPlayerViewModel()
        PlayerControlsView(viewModel: viewModel)
            .padding()
    }
}
