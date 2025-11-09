//
//  PlayerProgressView.swift
//  audio-earning
//
//  Created by Codex on 2025/11/01.
//

import SwiftUI

struct PlayerProgressView: View {
    let currentTime: TimeInterval
    let duration: TimeInterval
    let bufferedTime: TimeInterval?
    let onSeek: (TimeInterval) -> Void

    @State private var isDragging = false
    @State private var dragTime: TimeInterval = 0
#if os(iOS)
    @State private var haptic = UIImpactFeedbackGenerator(style: .soft)
#endif

    private let trackHeight: CGFloat = 6
    private let handleDiameter: CGFloat = 18

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PlayerPalette.capsuleFill)
                        .frame(height: trackHeight)

                    if let bufferedTime, duration > 0 {
                        Capsule()
                            .fill(PlayerPalette.accentGlow.opacity(0.6))
                            .frame(
                                width: width(for: bufferedTime, in: geometry.size.width),
                                height: trackHeight
                            )
                    }

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [PlayerPalette.accent, PlayerPalette.accentSoft],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width(for: activeTime, in: geometry.size.width), height: trackHeight)

                    Circle()
                        .fill(Color.white)
                        .frame(width: handleDiameter, height: handleDiameter)
                        .shadow(color: PlayerPalette.shadow.opacity(0.6), radius: 6, y: 3)
                        .overlay(
                            Circle()
                                .stroke(PlayerPalette.accent, lineWidth: 3)
                        )
                        .offset(x: handleOffset(in: geometry.size.width))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let clampedX = max(0, min(value.location.x, geometry.size.width))
                                    dragTime = time(at: clampedX, totalWidth: geometry.size.width)
#if os(iOS)
                                    haptic.prepare()
#endif
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    onSeek(dragTime)
#if os(iOS)
                                    haptic.impactOccurred(intensity: 0.4)
#endif
                                }
                        )

                    if isDragging {
                        Text(formattedTime(dragTime))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: PlayerPalette.shadow.opacity(0.4), radius: 8, y: 4)
                            )
                            .offset(x: handleOffset(in: geometry.size.width), y: -36)
                    }
                }
            }
            .frame(height: max(trackHeight, handleDiameter))
            .padding(.horizontal, handleDiameter / 2)

            HStack {
                Text(formattedTime(activeTime))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(PlayerPalette.mutedText)

                Spacer()

                Text(formattedTime(duration))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(PlayerPalette.mutedText)
            }
        }
    }

    private var activeTime: TimeInterval {
        isDragging ? dragTime : currentTime
    }

    private func width(for time: TimeInterval, in totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let fraction = max(0, min(time / duration, 1))
        return fraction * totalWidth
    }

    private func handleOffset(in totalWidth: CGFloat) -> CGFloat {
        let cappedWidth = width(for: activeTime, in: totalWidth)
        return max(0, min(cappedWidth, totalWidth)) - handleDiameter / 2
    }

    private func time(at xPosition: CGFloat, totalWidth: CGFloat) -> TimeInterval {
        guard duration > 0 else { return 0 }
        let progress = max(0, min(xPosition / totalWidth, 1))
        return progress * duration
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        guard time.isFinite && !time.isNaN else { return "--:--" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
