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
    private let flame = SceneArt.exhaust()
    private var stateMachine: GKStateMachine?

    var currentState: GKState? { stateMachine?.currentState }

    override init() {
        super.init()
        flame.position = CGPoint(x: 0, y: -44)
        flame.zPosition = -1
        addChild(flame)
        addChild(SceneArt.rocket())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Puts the rocket back at the start of a mission with a fresh state machine.
    func reset(launched: Bool) {
        removeAllActions()
        isHidden = false
        alpha = 1
        zRotation = 0
        let machine = GKStateMachine(states: [
            OnPadState(rocket: self), FlyingState(rocket: self), CrashedState(rocket: self), DockedState(rocket: self)
        ])
        stateMachine = machine
        machine.enter(launched ? FlyingState.self : OnPadState.self)
    }

    @discardableResult
    func enter(_ state: AnyClass) -> Bool {
        stateMachine?.enter(state) ?? false
    }

    func configure(cellSize: CGFloat) {
        setScale(cellSize * 0.6 / 100)
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
