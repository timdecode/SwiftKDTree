import Testing
import Glibc
@testable import SwiftKDTree

struct RandomNumberGeneratorWithSeed: RandomNumberGenerator {
    init(seed: Int) { srand48(seed) }
    func next() -> UInt64 {
        return withUnsafeBytes(of: drand48()) { $0.load(as: UInt64.self) }
    }
}

extension SIMD3: KDTreeVector where Scalar == Float {
    public static var dimensions: Int { 3 }
    public func component(_ index: Int) -> Float { self[index] }
    public func distanceSquared(_ other: SIMD3<Float>) -> Float {
        let diff = self - other
        return (diff * diff).sum()
    }
}

func distance_squared(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
    let d = a - b
    return (d * d).sum()
}

@Test
func buildAndQuery() {
    var rng = RandomNumberGeneratorWithSeed(seed: 42)
    let points = (0..<100).map { _ in SIMD3<Float>.random(in: -1.0...1.0, using: &rng) }
    let tree = StaticKDTree(points: points)
    let query = points[0]
    let result = Set(tree.points(within: 0.001, of: query).map { $0.1 })
    #expect(result.contains(query))
}
