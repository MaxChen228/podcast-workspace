//
//  WaveformView.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import SwiftUI

/// Waveform view rendered with Canvas.
/// Shows the audio waveform along with current playback progress.
struct WaveformView: View {
    let samples: [Float]       // Amplitude values (0.0 ~ 1.0)
    let progress: Double       // Playback progress (0.0 ~ 1.0)
    let height: CGFloat        // View height

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let barWidth: CGFloat = max(1.0, width / CGFloat(samples.count))
                let spacing: CGFloat = 0.5

                // Draw waveform bars
                for (index, sample) in samples.enumerated() {
                    let x = CGFloat(index) * barWidth
                    let barHeight = CGFloat(sample) * height * 0.8  // Keep bars within 80% of view height

                    // Compute rectangle for each bar
                    let rect = CGRect(
                        x: x,
                        y: (height - barHeight) / 2,
                        width: barWidth - spacing,
                        height: barHeight
                    )

                    // Determine whether this segment has been played
                    let isPlayed = CGFloat(index) / CGFloat(samples.count) < progress

                    // Fill with appropriate color
                    let color = isPlayed ? Color.accentColor : Color.gray.opacity(0.3)
                    context.fill(Path(rect), with: .color(color))
                }

                // Draw progress indicator line
                let progressX = width * progress
                let progressLine = Path { path in
                    path.move(to: CGPoint(x: progressX, y: 0))
                    path.addLine(to: CGPoint(x: progressX, y: height))
                }
                context.stroke(progressLine, with: .color(.accentColor), lineWidth: 2)
            }
        }
        .frame(height: height)
    }
}

/// Waveform container that handles loading state.
struct WaveformContainerView: View {
    let audioURL: URL?
    let progress: Double

    @State private var waveformData: WaveformGenerator.WaveformData?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Generating waveform...")
                    .frame(height: 80)
            } else if let waveformData = waveformData {
                WaveformView(
                    samples: waveformData.samples,
                    progress: progress,
                    height: 80
                )
            } else if let error = errorMessage {
                Text("Waveform failed to load: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(height: 80)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 80)
                    .overlay(
                        Text("No waveform data")
                            .foregroundColor(.gray)
                    )
            }
        }
        .onChange(of: audioURL) { _, newURL in
            if let url = newURL {
                loadWaveform(from: url)
            }
        }
        .onAppear {
            if let url = audioURL {
                loadWaveform(from: url)
            }
        }
    }

    private func loadWaveform(from url: URL) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let data = try await WaveformGenerator.generateWaveform(from: url, targetSampleCount: 500)
                await MainActor.run {
                    self.waveformData = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    VStack {
        // Example 1: static waveform
        WaveformView(
            samples: (0..<100).map { _ in Float.random(in: 0...1) },
            progress: 0.3,
            height: 80
        )
        .padding()

        // Example 2: different progress value
        WaveformView(
            samples: (0..<100).map { _ in Float.random(in: 0...1) },
            progress: 0.7,
            height: 80
        )
        .padding()
    }
}
