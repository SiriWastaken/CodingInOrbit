//
//  GlobalGameView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-19.
//

import SwiftUI

let gridSizeH: Int = 20
let gridSizeW: Int = 20

struct GlobalGameView: View {
    @State private var selectedIndex: Int?
    @FocusState private var isWorkspaceFocused: Bool
    @State private var codeLines: [CodeLine] = []
    @State private var typedCommand: String = ""
    @State private var rocket = Rocket()
    
    var workspaceHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("WORKSPACE")
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            
            Divider()
        }
    }
    
    var workspacePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            workspaceHeader
            WorkspaceContentView(
                codeLines: $codeLines,
                selectedIndex: $selectedIndex,
                isWorkspaceFocused: _isWorkspaceFocused
            )
        }
    }
    
    var gridView: some View {
        GeometryReader { geometry in
            ZStack {
                Image("SplashScreen")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(
                        Color.black.opacity(0.3)
                    )
                
                ForEach(0..<30) { _ in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.1...0.3)))
                        .frame(width: CGFloat.random(in: 1...2))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                }
                
                // MARK: - Rocket (Positioned on Grid)
                let cellSize = min(geometry.size.width, geometry.size.height) / CGFloat(gridSizeW)
                let xOffset = CGFloat(rocket.col) * cellSize + cellSize / 2
                let yOffset = CGFloat(rocket.row) * cellSize + cellSize / 2
                
                RocketView(rocket: rocket)
                    .frame(width: cellSize * 0.8, height: cellSize * 0.8)
                    .position(x: xOffset, y: yOffset)
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                workspacePanel
                    .frame(width: geometry.size.width * 0.5)
                
                gridView
                    .frame(width: geometry.size.width * 0.5)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    // Back action — will be handled by NavigationStack
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

#Preview {
    GlobalGameView()
}
