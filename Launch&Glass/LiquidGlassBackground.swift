//
//  LiquidGlassBackground.swift
//  PaycheckPlanner
//
//  Clean, collision-safe Liquid Glass background with optional parallax.
//  Uses namespaced keys to avoid redeclaration, and compiles even if CoreMotion is missing.
//

import SwiftUI
import CoreMotion

// MARK: - Namespaced Settings Keys (avoid global name clashes)
public enum LiquidGlassKeys {
    public static let enabled   = "liquidGlassEnabled"
    public static let parallax  = "liquidGlassParallaxEnabled"
    public static let depth     = "liquidGlassDepth" // 0=subtle, 1=medium, 2=bold
}

// MARK: - Motion Manager (parallax)
private final class LGMotionManager: ObservableObject {
    static let shared = LGMotionManager()

    #if targetEnvironment(simulator)
    // Sim has no real motion; keep values at 0.
    @Published var x: Double = 0
    @Published var y: Double = 0

    func start() {}
    func stop()  {}
    #else
    private let manager = CMMotionManager()
    private let queue = OperationQueue()
    @Published var x: Double = 0
    @Published var y: Double = 0

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        if manager.isDeviceMotionActive { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0 // 30 Hz
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            let pitch = max(min(m.attitude.pitch, 0.35), -0.35)
            let roll  = max(min(m.attitude.roll,  0.35), -0.35)
            DispatchQueue.main.async {
                self.x = roll
                self.y = pitch
            }
        }
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
        x = 0; y = 0
    }
    #endif
}

// MARK: - Background View

/// Use this as a layer behind your app content (e.g., inside a ZStack).
public struct LiquidGlassBackground: View {
    @AppStorage(LiquidGlassKeys.enabled)  private var enabled: Bool = true
    @AppStorage(LiquidGlassKeys.parallax) private var parallaxOn: Bool = false
    @AppStorage(LiquidGlassKeys.depth)    private var depth: Int = 0

    @StateObject private var motion = LGMotionManager.shared

    public init() {}

    public var body: some View {
        Group {
            if enabled {
                ZStack {
                    movingGradientLayer
                    Rectangle().fill(.ultraThinMaterial)
                }
                .ignoresSafeArea()
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }
        }
        .onAppear { if parallaxOn { motion.start() } }
        .onChange(of: parallaxOn) { _, newVal in newVal ? motion.start() : motion.stop() }
        .onDisappear { motion.stop() }
    }

    // MARK: - Layers

    private var movingGradientLayer: some View {
        let amplitude: CGFloat = {
            switch depth {
            case 2: return 18     // bold
            case 1: return 10     // medium
            default: return 6     // subtle
            }
        }()
        let xOffset = parallaxOn ? CGFloat(motion.x) * amplitude : 0
        let yOffset = parallaxOn ? CGFloat(motion.y) * amplitude : 0

        return LinearGradient(
            colors: [
                Color(.systemBackground).opacity(0.92),
                Color(.secondarySystemBackground).opacity(0.92),
                Color(.tertiarySystemBackground).opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blur(radius: 8)
        .saturation(1.05)
        .offset(x: xOffset, y: yOffset)
        .scaleEffect(1.03) // avoid edge reveal when offsetting
        .accessibilityHidden(true)
    }
}
