import XCTest
import simd

@testable import SwiftKDTree

extension simd_float3: Vector {
    public typealias Component = Float

    public static var dimensions: Int {
        3
    }
    
    public func component(_ index: Int) -> Float {
        switch index {
        case 0: return self.x
        case 1: return self.y
        case 2: return self.z
        default: fatalError()
        }
    }
    
    public func distanceSquared(_ other: SIMD3<Scalar>) -> Float {
        return simd.distance_squared(self, other)
    }
}

final class SwiftKDTreeTests: XCTestCase {
    func testExample() throws {
        let points: [simd_float3] = (0..<100).map { _ in
            return simd_float3.random(in: -1.0...1.0 )
        }
        
        let tree = StaticKDTree(points: points)
        
        let query = simd_float3(0.1, 0.1, 0.1)
        let radius: Float = 0.7
        
        let answer = points.filter { p in
            distance(p, query) < radius
        }
        let answerSet = Set<simd_float3>(answer)
        
        let result = tree.points(within: radius, of: query)
        let resultSet = Set<simd_float3>(result)
        
        for p in result {
            XCTAssertTrue( answerSet.contains(p) )
        }
        
        for p in answer {
            XCTAssertTrue( resultSet.contains(p) )
        }
        
        XCTAssertTrue( result.count == answer.count )
    }

}
