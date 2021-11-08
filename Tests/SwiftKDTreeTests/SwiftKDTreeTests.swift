import XCTest
import simd

import SwiftKDTree
//import KDTree

extension simd_float3: KDTreeVector {
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

//extension simd_float3: KDTreePoint {
//    public func kdDimension(_ dimension: Int) -> Double {
//        return Double(component(dimension))
//    }
//
//    public func squaredDistance(to otherPoint: SIMD3<Scalar>) -> Double {
//        return Double( simd.distance_squared(self, otherPoint) )
//    }
//}

final class SwiftKDTreeTests: XCTestCase {
    var timingPoints: [simd_float3] = []
    var neighbourPoints: [simd_float3] = []
    
    override func setUp() {
        timingPoints = (0..<100_000).map { _ in
            return simd_float3.random(in: -1.0...1.0)
        }
        
        neighbourPoints = (0..<100_000).map { _ in
            return simd_float3.random(in: -1.0...1.0 )
        }
    }
    
    func testPointsWithin_array() throws {
        let tree = StaticKDTree(points: neighbourPoints)
        
        for _ in 0..<100 {
            let query = simd_float3.random(in: -1.0...1.0 )
            let radius: Float = 0.2
            
            let answer = neighbourPoints.filter { p in
                distance(p, query) < radius
            }
            let answerSet = Set<simd_float3>(answer)
            
            let result = tree.points(within: radius, of: query).map { $0.0 }
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
    
    func testPointsWithin_callback() throws {
        let tree = StaticKDTree(points: neighbourPoints)
        
        let query = simd_float3(0.1, 0.1, 0.1)
        let radius: Float = 0.7
        
        let answer = neighbourPoints.filter { p in
            distance(p, query) < radius
        }
        let answerSet = Set<simd_float3>(answer)
        
        var resultSet = Set<simd_float3>()
        
        tree.points(within: radius, of: query) { p, i in
            resultSet.insert(p)
        }
        
        for p in resultSet {
            XCTAssertTrue( answerSet.contains(p) )
        }
        
        for p in answer {
            XCTAssertTrue( resultSet.contains(p) )
        }
        
        XCTAssertTrue( resultSet.count == answer.count )
    }
    
    func testPointsWithin_indices() throws {
        let tree = StaticKDTree(points: neighbourPoints)
        
        let query = simd_float3(0.1, 0.1, 0.1)
        let radius: Float = 0.7
        
        let answer = Set<Int>(neighbourPoints.enumerated().filter { (i,p) in
            distance(p, query) < radius
        }.map { $0.offset } )
        
        var result: [Int] = []
        
        tree.points(within: radius, of: query) { (_, i) in
            result.append(i)
        }
        
        XCTAssertTrue( result.count == answer.count )

        for i in result {
            XCTAssertTrue( answer.contains(i))
        }
    }

//    func testBersaelor() throws {
//        measure {
//            let kdTree = KDTree(values: timingPoints)
//        }
//    }
    
    func testOurs() throws {
        measure {
            let kdTree = StaticKDTree(points: timingPoints)
        }
    }
}

