import XCTest
import simd

import SwiftKDTree

struct RandomNumberGeneratorWithSeed: RandomNumberGenerator {
    init(seed: Int) {
        // Set the random seed
        srand48(seed)
    }
    
    func next() -> UInt64 {
        // drand48() returns a Double, transform to UInt64
        return withUnsafeBytes(of: drand48()) { bytes in
            bytes.load(as: UInt64.self)
        }
    }
}

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

final class SwiftKDTreeTests: XCTestCase {
    struct TestData {
        let points: [simd_float3]
        let tree: StaticKDTree<simd_float3>
        let queries: [simd_float3]
        
        init() {
            self.points = []
            self.tree = .init(points: [])
            self.queries = []
        }
        
        init(points: [simd_float3], tree: StaticKDTree<simd_float3>, queries: [simd_float3]) {
            self.points = points
            self.tree = tree
            self.queries = queries
        }
    }
    
    static var testData: TestData = .init()
    
    var tree: StaticKDTree<simd_float3> { Self.testData.tree }
    var neighbourPoints: [simd_float3] { Self.testData.points }
    var queryPoints: [simd_float3] { Self.testData.queries }
    
    override class func setUp() {
        var generator = RandomNumberGeneratorWithSeed(seed: 49)
        
        var points = (0..<100_000).map { _ in
            return simd_float3.random(in: -1.0...1.0, using: &generator)
        }
        
        // append some duplicates
        for _ in 0..<1000 {
            points.append(points.randomElement(using: &generator)!)
        }
        
        // add some difficult cases
        for c in 0..<3 {
            let v = points[0][c]

            var point = simd_float3.random(in: -1.0...1.0, using: &generator)

            // duplicate a dimension
            point[c] = v

            points.append(point)
        }
        
        let kdTree = StaticKDTree(points: points)
        
        // queries
        var queries: [simd_float3] = (0..<100).map { _ in simd_float3.random(in: -1.0...1.0, using: &generator)}
        // add some points from the main points
        for _ in 0..<100 {
            queries.append(points.randomElement(using: &generator)!)
        }
        
        queries.append(contentsOf: points.suffix(3))
        
        testData = .init(points: points, tree: kdTree, queries: queries)
        
        
    }
    
    func testPointsWithin_array() throws {
        for query in queryPoints {
            let radius: Float = 0.2
            
            let answer = neighbourPoints.filter { p in
                distance_squared(p, query) < radius * radius + Float.ulpOfOne
            }
            let answerSet = Set<simd_float3>(answer)
            
            let result = tree.points(within: radius, of: query).map { $0.1 }
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
    
    func testPointsWithin_mutualality() throws {
        for query in queryPoints {
            let radius: Float = 0.05
            
            let result = tree.points(within: radius, of: query)
            
            for (i, p) in result {
                let others = tree.points(within: radius, of: p)
                
                XCTAssert( others.contains(where: { (j, _) in
                    j == i
                }))
            }
        }
    }
    
    func testPointsWithin_callback() throws {
        let query = simd_float3(0.1, 0.1, 0.1)
        let radius: Float = 0.7
        
        let answer = neighbourPoints.filter { p in
            distance(p, query) < radius
        }
        let answerSet = Set<simd_float3>(answer)
        
        var result: [simd_float3] = []
        var resultSet = Set<simd_float3>()
        
        tree.points(within: radius, of: query) { _, p in
            resultSet.insert(p)
            result.append(p)
        }
        
        for p in resultSet {
            XCTAssertTrue( answerSet.contains(p) )
        }
        
        for p in answer {
            XCTAssertTrue( resultSet.contains(p) )
        }
        
        XCTAssertTrue( answer.count == result.count )
        XCTAssertTrue( result.count == answer.count )
    }
    
    func testPointsWithin_indices() throws {
        for query in queryPoints {
            let radius: Float = 0.7
            
            let answer = Set<Int>(neighbourPoints.enumerated().filter { (i,p) in
                distance_squared(p, query) < radius * radius + Float.ulpOfOne
            }.map { $0.offset } )
            
            var result: [Int] = []
            
            tree.points(within: radius, of: query) { (i, _) in
                result.append(i)
            }
            
            XCTAssertTrue( result.count == answer.count )
            
            for i in result {
                XCTAssertTrue( answer.contains(i))
            }
        }
    }

    
    func testSetup() throws {
        measure {
            _ = StaticKDTree(points: neighbourPoints)
        }
    }
}

final class KDTreeCollectionTests: XCTestCase {
    struct TestData {
        let points: [simd_float3]
        let tree: KDTreeCollection<simd_float3>
        let queries: [simd_float3]
        
        init() {
            self.points = []
            self.tree = .init(points: [], maxLeafSize: 10)
            self.queries = []
        }
        
        init(points: [simd_float3], tree: StaticKDTree<simd_float3>, queries: [simd_float3]) {
            self.points = points
            self.tree = .init(points: points, maxLeafSize: 10)
            self.queries = queries
        }
    }
    
    static var testData: TestData = .init()
    
    var tree: KDTreeCollection<simd_float3> { Self.testData.tree }
    var neighbourPoints: [simd_float3] { Self.testData.points }
    var queryPoints: [simd_float3] { Self.testData.queries }
    
    override class func setUp() {
        var generator = RandomNumberGeneratorWithSeed(seed: 49)
        
        var points = (0..<100_000).map { _ in
            return simd_float3.random(in: -1.0...1.0, using: &generator)
        }
        
        // append some duplicates
        for _ in 0..<1000 {
            points.append(points.randomElement(using: &generator)!)
        }
        
        // add some difficult cases
        for c in 0..<3 {
            let v = points[0][c]

            var point = simd_float3.random(in: -1.0...1.0, using: &generator)

            // duplicate a dimension
            point[c] = v

            points.append(point)
        }
        
        let kdTree = StaticKDTree(points: points)
        
        // queries
        var queries: [simd_float3] = (0..<100).map { _ in simd_float3.random(in: -1.0...1.0, using: &generator)}
        // add some points from the main points
        for _ in 0..<100 {
            queries.append(points.randomElement(using: &generator)!)
        }
        
        queries.append(contentsOf: points.suffix(3))
        
        testData = .init(points: points, tree: kdTree, queries: queries)
    }
    
    func testSetup() throws {
        measure {
            _ = KDTreeCollection(points: neighbourPoints, maxLeafSize: 10)
        }
    }
    
    func testPointsWithin_array() throws {
        for query in queryPoints {
            let radius: Float = 0.2

            let answer = neighbourPoints.filter { p in
                distance_squared(p, query) < radius * radius + Float.ulpOfOne
            }
            let answerSet = Set<simd_float3>(answer)

            let result = tree.points(within: radius, of: query).map { $0.1 }
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
//
//    func testPointsWithin_mutualality() throws {
//        for query in queryPoints {
//            let radius: Float = 0.05
//
//            let result = tree.points(within: radius, of: query)
//
//            for (i, p) in result {
//                let others = tree.points(within: radius, of: p)
//
//                XCTAssert( others.contains(where: { (j, _) in
//                    j == i
//                }))
//            }
//        }
//    }
//
    func testPointsWithin_callback() throws {
        let query = simd_float3(0.1, 0.1, 0.1)
        let radius: Float = 0.7

        let answer = neighbourPoints.filter { p in
            distance(p, query) < radius
        }
        let answerSet = Set<simd_float3>(answer)

        var result: [simd_float3] = []
        var resultSet = Set<simd_float3>()

        tree.points(within: radius, of: query) { _, p in
            resultSet.insert(p)
            result.append(p)
            
            return true
        }

        for p in resultSet {
            XCTAssertTrue( answerSet.contains(p) )
        }

        for p in answer {
            XCTAssertTrue( resultSet.contains(p) )
        }

        XCTAssertTrue( answer.count == result.count )
        XCTAssertTrue( result.count == answer.count )
    }
//
//    func testPointsWithin_indices() throws {
//        for query in queryPoints {
//            let radius: Float = 0.7
//
//            let answer = Set<Int>(neighbourPoints.enumerated().filter { (i,p) in
//                distance_squared(p, query) < radius * radius + Float.ulpOfOne
//            }.map { $0.offset } )
//
//            var result: [Int] = []
//
//            tree.points(within: radius, of: query) { (i, _) in
//                result.append(i)
//            }
//
//            XCTAssertTrue( result.count == answer.count )
//
//            for i in result {
//                XCTAssertTrue( answer.contains(i))
//            }
//        }
//    }

}
