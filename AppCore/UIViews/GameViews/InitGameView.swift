//
//  SwiftUIView.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-06-16.
//

import SwiftUI

// this file calls other UI Views, Managers, and Engines. It DOES NOT do anything by itself except for purely rendering. This is a global file that defines the shape of lessons, and there are lesson files which display and render lesson-specific content. I've decided to design it in this way to make turning this proof-of-concept for the swift student challenge into a real app much easier

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
