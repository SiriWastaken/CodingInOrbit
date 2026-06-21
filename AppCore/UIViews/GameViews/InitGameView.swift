//
//  SwiftUIView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-16.
//

import SwiftUI

struct InitGameView: View {
    var body: some View {
        ZStack {
            Image("SplashScreen")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.3)  
            
            CarouselView()
        }
    }
}

#Preview {
    InitGameView()
}
