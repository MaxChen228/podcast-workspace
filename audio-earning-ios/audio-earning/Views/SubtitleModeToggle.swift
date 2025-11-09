//
//  SubtitleModeToggle.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import SwiftUI

/// Subtitle display mode toggle.
struct SubtitleModeToggle: View {
    @ObservedObject var viewModel: AudioPlayerViewModel

    var body: some View {
        Picker("Subtitle Mode", selection: Binding(
            get: { viewModel.displayMode },
            set: { viewModel.setDisplayMode($0) }
        )) {
            ForEach(SubtitleDisplayMode.allCases, id: \.self) { mode in
                Text(mode.description)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 200)
    }
}

/// Styled variant (optional).
struct SubtitleModeToggleStyled: View {
    @ObservedObject var viewModel: AudioPlayerViewModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SubtitleDisplayMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.setDisplayMode(mode)
                    }
                }) {
                    Text(mode.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(viewModel.displayMode == mode ? .white : .accentColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.displayMode == mode ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 30) {
        // Preview default style
        SubtitleModeToggle(viewModel: AudioPlayerViewModel())
            .padding()

        // Preview styled version
        SubtitleModeToggleStyled(viewModel: AudioPlayerViewModel())
            .padding()
    }
}
