//
//  RocketNode.swift
//  Coding In Orbit
//
//  Created by Sri Ganty on 2026-09-30.
//

import SpriteKit
import GameplayKit

// The rocket on screen. A GameplayKit state machine tracks where it is in its journey
// (on the pad → flying → crashed or docked) and only allows moves that make sense,
// like no takeoff after a crash until the mission resets.

enum FlameLevel {
    case off, cruise, boost

    var birthRate: CGFloat {
        switch self {
        case .off: 0
        case .cruise: 90
        case .boost: 420
        }
    }

    var speed: CGFloat {
        switch self {
        case .off, .cruise: 160
        case .boost: 300
        }
    }
}

final class RocketNode: SKNode {
    /// Holds the drawing, flame, and helmet. The node itself turns to face the heading,
    /// while this inner layer is free to wiggle, hop, and squash.
    private let art = SKNode()
    private let flame = SceneArt.exhaust()
    private let halo = SceneArt.glow(color: Palette.goldTrim, diameter: 120, alpha: 0)
    private var helmet: SKNode?
    private var stateMachine: GKStateMachine?
    private var reduceMotion = false

    var currentState: GKState? { stateMachine?.currentState }
    var isSuitedUp: Bool { helmet != nil }

    override init() {
        super.init()
        halo.zPosition = -2
        addChild(halo)
        flame.position = CGPoint(x: 0, y: -44)
        flame.zPosition = -1
        art.addChild(flame)
        art.addChild(SceneArt.rocket())
        addChild(art)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Puts the rocket back at the start of a mission with a fresh state machine.
    func reset(launched: Bool, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        removeAllActions()
        art.removeAllActions()
        art.position = .zero
        art.zRotation = 0
        art.setScale(1)
        isHidden = false
        alpha = 1
        zRotation = 0
        let machine = GKStateMachine(states: [
            OnPadState(rocket: self), FlyingState(rocket: self), CrashedState(rocket: self), DockedState(rocket: self)
        ])
        stateMachine = machine
        machine.enter(launched ? FlyingState.self : OnPadState.self)
        startIdling()
    }

    @discardableResult
    func enter(_ state: AnyClass) -> Bool {
        stateMachine?.enter(state) ?? false
    }

    /// The rocket art is about 100 points tall; this scales it to the height it should be on screen.
    static func scale(forHeight height: CGFloat) -> CGFloat { height / 100 }

    func configure(height: CGFloat) {
        setScale(Self.scale(forHeight: height))
    }

    /// Settles onto the ground with the engine off.
    func land() {
        enter(DockedState.self)
        stopIdling()
    }

    func setFlame(_ level: FlameLevel) {
        flame.particleBirthRate = level.birthRate
        flame.particleSpeed = level.speed
    }

    /// A big burst of thrust that settles back to a cruising flame.
    func boost(for duration: TimeInterval) {
        setFlame(.boost)
        run(.sequence([
            .wait(forDuration: duration),
            .run { [weak self] in self?.setFlame(.cruise) }
        ]), withKey: "boost")
    }

    // MARK: Personality

    /// While waiting, the rocket sways and bobs a little, like it's humming to itself.
    func startIdling() {
        art.removeAction(forKey: "idle")
        guard !reduceMotion else { return }
        let sway = SKAction.sequence([
            .rotate(toAngle: 0.06, duration: 1.1),
            .rotate(toAngle: -0.05, duration: 1.3),
            .rotate(toAngle: 0, duration: 0.9),
            .wait(forDuration: 1.6)
        ])
        sway.timingMode = .easeInEaseOut
        let bob = SKAction.sequence([.moveBy(x: 0, y: 4, duration: 1.4), .moveBy(x: 0, y: -4, duration: 1.4)])
        bob.timingMode = .easeInEaseOut
        art.run(.repeatForever(.group([sway, bob])), withKey: "idle")
    }

    func stopIdling() {
        art.removeAction(forKey: "idle")
        art.run(.group([.rotate(toAngle: 0, duration: 0.15), .move(to: .zero, duration: 0.15)]))
    }

    /// A happy little hop and a warm glow after a command works.
    func react(after delay: TimeInterval) {
        let glowUp = SKAction.sequence([.wait(forDuration: delay), .fadeAlpha(to: 0.55, duration: 0.08), .fadeAlpha(to: 0, duration: 0.45)])
        halo.run(glowUp, withKey: "react")
        guard !reduceMotion else { return }
        let squash = SKAction.scaleX(to: 1.12, y: 0.9, duration: 0.07)
        let stretch = SKAction.scaleX(to: 0.94, y: 1.1, duration: 0.09)
        let settle = SKAction.scale(to: 1, duration: 0.16)
        settle.timingMode = .easeOut
        art.run(.sequence([.wait(forDuration: delay), squash, stretch, settle]), withKey: "react")
    }

    /// A wave hello: a happy spin with a little hop.
    func wave() {
        guard !reduceMotion else {
            react(after: 0)
            return
        }
        let hop = SKAction.sequence([.moveBy(x: 0, y: 18, duration: 0.18), .moveBy(x: 0, y: -18, duration: 0.22)])
        hop.timingMode = .easeInEaseOut
        art.run(.group([hop, .sequence([.rotate(byAngle: 0.35, duration: 0.12), .rotate(byAngle: -0.7, duration: 0.18), .rotate(byAngle: 0.35, duration: 0.12)])]))
        react(after: 0.1)
    }

    /// Astronaut mode: a helmet with a blinking antenna pops on.
    func suitUp() {
        guard helmet == nil else {
            wave()
            return
        }
        let newHelmet = SceneArt.helmet()
        newHelmet.setScale(0.1)
        newHelmet.zPosition = 1
        let pop = SKAction.scale(to: 1.15, duration: 0.18)
        pop.timingMode = .easeOut
        newHelmet.run(.sequence([pop, .scale(to: 1, duration: 0.12)]))
        art.addChild(newHelmet)
        helmet = newHelmet
        react(after: 0.2)
    }
}

// MARK: - States

class RocketState: GKState {
    unowned let rocket: RocketNode

    init(rocket: RocketNode) {
        self.rocket = rocket
        super.init()
    }
}

final class OnPadState: RocketState {
    override func didEnter(from previousState: GKState?) {
        let rocket = rocket
        MainActor.assumeIsolated { rocket.setFlame(.off) }
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass is FlyingState.Type
    }
}

final class FlyingState: RocketState {
    override func didEnter(from previousState: GKState?) {
        let rocket = rocket
        MainActor.assumeIsolated { rocket.setFlame(.cruise) }
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        stateClass is CrashedState.Type || stateClass is DockedState.Type
    }
}

final class CrashedState: RocketState {
    override func didEnter(from previousState: GKState?) {
        let rocket = rocket
        MainActor.assumeIsolated {
            rocket.setFlame(.off)
            rocket.isHidden = true
        }
    }

    // Crashed is the end of the line until the mission resets.
    override func isValidNextState(_ stateClass: AnyClass) -> Bool { false }
}

final class DockedState: RocketState {
    override func didEnter(from previousState: GKState?) {
        let rocket = rocket
        MainActor.assumeIsolated { rocket.setFlame(.off) }
    }

    override func isValidNextState(_ stateClass: AnyClass) -> Bool { false }
}
