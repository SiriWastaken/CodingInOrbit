//
//  HomeView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-17.
//

import SwiftUI

struct HomeView: View {
    @StateObject var accessibilityManager = AccessibilityManager()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Image("SplashScreen")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.6),
                                Color.clear,
                                Color.black.opacity(0.4)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                ForEach(0..<30) { _ in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.1...0.4)))
                        .frame(width: CGFloat.random(in: 1...3))
                        .position(
                            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                        )
                }
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("CODING IN")
                            .font(.system(size: 32, weight: .light, design: .serif))
                            .kerning(6)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("ORBIT")
                            .font(.system(size: 56, weight: .bold, design: .serif))
                            .kerning(8)
                            .foregroundColor(.white)
                            .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 0)
                    }
                    
                    Text("Learn coding by exploring the unknown!")
                        .font(.subheadline)
                        .fontWeight(.light)
                        .kerning(2)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 20)
                    
                    NavigationLink(destination: GameView()
                        .environmentObject(accessibilityManager)
                    ) {
                        Text("LIFTOFF")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .tracking(2)
                            .frame(width: 220, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.black, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 6)
                    }
                    .applyAccessibility(accessibilityManager)
                    
                    NavigationLink(destination: OptionsView()
                        .environmentObject(accessibilityManager)
                    ) {
                        Text("OPTIONS")
                            .font(.headline)
                            .fontWeight(.medium)
                            .tracking(2)
                            .frame(width: 220, height: 48)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .applyAccessibility(accessibilityManager)
                    
                    NavigationLink(destination: CreditsView()
                        .environmentObject(accessibilityManager)
                    ) {
                        Text("CREDITS")
                            .font(.headline)
                            .fontWeight(.medium)
                            .tracking(2)
                            .frame(width: 220, height: 48)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .applyAccessibility(accessibilityManager)
                    
                    Spacer()
                    
                }
                .padding(.horizontal, 40)
            }
            .navigationBarHidden(true)
        }
        .environmentObject(accessibilityManager)
        .applyAccessibility(accessibilityManager)
    }
}

#Preview {
    HomeView()
}
