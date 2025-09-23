//
//  ContentView.swift
//  gestures
//
//  Created by Mimi Chen on 9/18/25.
//

import SwiftUI

struct ContentView: View {
    @State private var catPosition: CGFloat = 200
    @State private var catVelocity: CGFloat = 0
    @State private var gameTimer: Timer?
    @State private var obstacleTimer: Timer?
    @State private var obstacles: [Obstacle] = []
    @State private var isGameActive = false
    @State private var score = 0
    @State private var gameOver = false
    @State private var isHolding = false
    @State private var holdTimer: Timer?
    @State private var backgroundOffset: CGFloat = 0
    @State private var cloudOffset: CGFloat = 0
    @State private var screenSize: CGSize = .zero
    
    @State private var holdDuration: TimeInterval = 0
    @State private var lastHoldTime: Date = Date()
    
    let catSize: CGFloat = 64
    let gravity: CGFloat = 0.3
    let baseHoldPower: CGFloat = 0.8
    let maxHoldPower: CGFloat = 1.2
    let holdBuildUpRate: CGFloat = 2.0
    let maxVelocity: CGFloat = 8
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated Background
                backgroundView(geometry: geometry)
                
                // Game Elements
                if isGameActive || gameOver {
                    gamePlayView(geometry: geometry)
                } else {
                    startScreenView
                }
                
                // UI Overlay
                VStack {
                    HStack {
                        Text("Score: \(score)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 52)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    Spacer()
                }
                
                // Game Over Screen
                if gameOver {
                    gameOverView
                }
            }
            .onAppear {
                screenSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newSize in
                screenSize = newSize
            }
        }
        .ignoresSafeArea(.all)
        .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
            if isGameActive && !gameOver {
                updateGame()
            }
            animateBackground()
        }
    }
    
    private func backgroundView(geometry: GeometryProxy) -> some View {
        ZStack {
            // Sky gradient
            LinearGradient(
                colors: [
                    Color(red: 0.6, green: 0.9, blue: 1.0),
                    Color(red: 0.8, green: 0.95, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Clouds
            ForEach(0..<4, id: \.self) { i in
                cloudView
                    .offset(x: cloudOffset + CGFloat(i * 180) - 300, y: CGFloat(i * 25) + 40)
                    .opacity(0.7)
            }
            
            // Ground
            VStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.8, blue: 0.3),
                                Color(red: 0.3, green: 0.6, blue: 0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 60)
                    .overlay(
                        // Grass pattern
                        HStack(spacing: 15) {
                            ForEach(0..<25, id: \.self) { _ in
                                grassTuft
                            }
                        }
                        .offset(x: backgroundOffset),
                        alignment: .top
                    )
            }
        }
    }
    
    private var cloudView: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 35, height: 35)
            Circle()
                .fill(Color.white)
                .frame(width: 40, height: 40)
                .offset(x: 12)
            Circle()
                .fill(Color.white)
                .frame(width: 30, height: 30)
                .offset(x: 25)
            Circle()
                .fill(Color.white)
                .frame(width: 38, height: 38)
                .offset(x: -15)
        }
    }
    
    private var grassTuft: some View {
        VStack(spacing: 1) {
            Rectangle()
                .fill(Color(red: 0.2, green: 0.7, blue: 0.2))
                .frame(width: 2, height: 12)
            Rectangle()
                .fill(Color(red: 0.2, green: 0.7, blue: 0.2))
                .frame(width: 2, height: 10)
                .offset(x: 2)
            Rectangle()
                .fill(Color(red: 0.2, green: 0.7, blue: 0.2))
                .frame(width: 2, height: 14)
                .offset(x: -1)
        }
    }
    
    private func gamePlayView(geometry: GeometryProxy) -> some View {
        ZStack {
            // Invisible touch area covering the entire screen
            Rectangle()
                .fill(Color.clear)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isHolding {
                                startHolding()
                            }
                        }
                        .onEnded { _ in
                            stopHolding()
                        }
                )
            
            // Cat
            catView
                .position(x: 120, y: catPosition)
                .animation(.easeOut(duration: 0.1), value: catPosition)
            
            // Obstacles
            ForEach(obstacles) { obstacle in
                obstacleView(obstacle: obstacle, geometry: geometry)
            }
        }
    }
    
    private var catView: some View {
        ZStack {
            // Hold power indicator
            if isHolding {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 60 + (holdDuration * 30), height: 60 + (holdDuration * 30))
                    .opacity(0.5)
                    .animation(.easeInOut(duration: 0.1), value: holdDuration)
            }
            
            // Cat character
            Image("stawberry siamese")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: catSize, height: catSize)
                .rotationEffect(.degrees(catVelocity * 2))
                .scaleEffect(isHolding ? 1.0 + (holdDuration * 0.2) : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isHolding)
                .animation(.easeInOut(duration: 0.1), value: holdDuration)
        }
    }
    
    private func obstacleView(obstacle: Obstacle, geometry: GeometryProxy) -> some View {
        ZStack {
            // Top barrier
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.3, blue: 0.2),
                            Color(red: 0.5, green: 0.4, blue: 0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 50, height: obstacle.gapY - 180)
                .position(x: obstacle.x, y: (obstacle.gapY - 180) / 2)
            
            // Bottom barrier
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.3, blue: 0.2),
                            Color(red: 0.5, green: 0.4, blue: 0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 50, height: geometry.size.height - obstacle.gapY - 180)
                .position(x: obstacle.x, y: obstacle.gapY + 180 + (geometry.size.height - obstacle.gapY - 180) / 2)
            
            // Decorative elements on barriers
            VStack {
                decorativePattern
                    .position(x: obstacle.x, y: obstacle.gapY - 200)
                Spacer()
                decorativePattern
                    .position(x: obstacle.x, y: obstacle.gapY + 200)
            }
        }
    }
    
    private var decorativePattern: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Color(red: 0.6, green: 0.5, blue: 0.4))
                    .frame(width: 4, height: 4)
            }
        }
    }
    
    private var startScreenView: some View {
        VStack(spacing: 25) {
            VStack(spacing: 8) {
                Image("stawberry siamese")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                
                Text("cat flappy")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 3)
                
            }
            
            VStack(spacing: 12) {
                Text("hold longer for more lift! 🎈")
                    .font(.body)
                    .foregroundColor(.white)
                    .shadow(color: .black, radius: 2)
                    .multilineTextAlignment(.center)
                
                Text("quick taps = gentle float\nlong holds = powerful boost")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black, radius: 1)
                    .multilineTextAlignment(.center)
                
                Button("start flapping") {
                    startGame()
                }
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 25)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ).opacity(0.75)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                )
                .scaleEffect(1.0 + sin(Date().timeIntervalSince1970 * 3) * 0.05)
            }
        }
    }
    
    private var gameOverView: some View {
        VStack(spacing: 20) {
            Text("game over! 😿")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 3)
            
            Text("final score: \(score)")
                .font(.title2)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 2)
            
            Button("try again") {
                restartGame()
            }
            .font(.title3)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 25)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.green, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ).opacity(0.75)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.3))
                .blur(radius: 1)
        )
    }
    
    // MARK: - Game Logic
    
    private func startGame() {
        isGameActive = true
        gameOver = false
        score = 0
        catPosition = 200
        catVelocity = 0
        holdDuration = 0
        obstacles.removeAll()
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            updateGame()
        }
        
        obstacleTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            addObstacle()
        }
    }
    
    private func updateGame() {
        // Apply gravity
        catVelocity += gravity
        
        // Calculate hold power based on duration
        let currentHoldPower = calculateHoldPower()
        
        // Apply hold power if holding
        if isHolding {
            catVelocity -= currentHoldPower
        }
        
        // Limit velocity
        catVelocity = max(-maxVelocity, min(maxVelocity, catVelocity))
        catPosition += catVelocity
        
        // Check boundaries
        if catPosition < 10 || catPosition > screenSize.height - 70 {
            endGame()
            return
        }
        
        // Move obstacles
        for i in obstacles.indices {
            obstacles[i].x -= 2.5
        }
                obstacles = obstacles.filter { obstacle in
            if obstacle.x < -50 && !obstacle.scored {
                score += 1
                return false
            }
            return obstacle.x > -50
        }
        
        // Check collisions
        checkCollisions()
    }
    
    private func calculateHoldPower() -> CGFloat {
        // Progressive power based on how long the hold has been sustained
        let powerMultiplier = min(holdDuration * holdBuildUpRate, 3.0) // Cap at 3x
        return baseHoldPower + (powerMultiplier * 0.3)
    }
    
    private func checkCollisions() {
        for obstacle in obstacles {
            let catRect = CGRect(x: 100, y: catPosition - catSize/2, width: catSize, height: catSize)
            let topRect = CGRect(x: obstacle.x - 25, y: 0, width: 50, height: obstacle.gapY - 180)
            let bottomRect = CGRect(x: obstacle.x - 25, y: obstacle.gapY + 180, width: 50, height: screenSize.height)
            
            if catRect.intersects(topRect) || catRect.intersects(bottomRect) {
                endGame()
                return
            }
        }
    }
    
    private func addObstacle() {
        let gapY = CGFloat.random(in: 150...400)
        obstacles.append(Obstacle(x: screenSize.width + 50, gapY: gapY))
    }
    
    private func startHolding() {
        isHolding = true
        lastHoldTime = Date()
        holdDuration = 0
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            self.holdDuration = Date().timeIntervalSince(self.lastHoldTime)
        }
    }
    
    private func stopHolding() {
        isHolding = false
        holdTimer?.invalidate()
        holdDuration = 0
    }
    
    private func endGame() {
        gameOver = true
        isGameActive = false
        gameTimer?.invalidate()
        obstacleTimer?.invalidate()
        holdTimer?.invalidate()
    }
    
    private func restartGame() {
        startGame()
    }
    
    private func animateBackground() {
        backgroundOffset -= 1
        if backgroundOffset < -200 {
            backgroundOffset = 0
        }
        
        cloudOffset -= 0.5
        if cloudOffset < -1000 {
            cloudOffset = 0
        }
    }
}

// MARK: - Models
struct Obstacle: Identifiable {
    let id = UUID()
    var x: CGFloat
    let gapY: CGFloat
    var scored = false
}

// MARK: - Helper Views
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

#Preview {
    ContentView()
}
