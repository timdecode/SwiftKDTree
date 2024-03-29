//
//  KDTreeCollection+KNearest.swift
//  
//
//  Created by Timothy Davison on 2021-11-11.
//

import Foundation

extension KDTreeCollection {
    public struct KNearest {
        public var indices: [Int]
        public var points: [Element]
        public var distancesSqrd: [Component]
        public let k: Int
        
        @inlinable
        public init(k: Int) {
            self.indices = []
            self.indices.reserveCapacity(k)
            
            self.points = []
            self.points.reserveCapacity(k)

            self.distancesSqrd = []
            self.distancesSqrd.reserveCapacity(k)

            self.k = k

        }
        
        @inlinable
        mutating func reset() {
            indices.removeAll(keepingCapacity: true)
            points.removeAll(keepingCapacity: true)
            distancesSqrd.removeAll(keepingCapacity: true)
        }
        
        @inlinable
        mutating func nearest(to query: Element, tree: KDTreeCollection) {
            reset()
            
            let capacity = k
                    
            distancesSqrd.append(contentsOf: repeatElement(0.0, count: capacity))
            indices.append(contentsOf: repeatElement(-1, count: capacity))
            
            distancesSqrd[capacity - 1] = .infinity

            var count = 0

            tree.search(query: query) {
                return distancesSqrd.last!
            } result: { treeIndex, distanceSqrd in
                let i: Int = {
                    // Slide everything larger than the distance over.
                    // The last position contains the largest index
                    for i in stride(from: count, to: 0, by: -1) {
                        if distancesSqrd[i - 1] > distanceSqrd {
                            if i < capacity {
                                distancesSqrd[i] = distancesSqrd[i - 1]
                                indices[i] = indices[i - 1]
                            }
                        } else {
                            return i
                        }
                    }

                    return 0
                }()

                if i < capacity {
                    distancesSqrd[i] = distanceSqrd
                    indices[i] = treeIndex
                }

                if count < capacity {
                    count += 1
                }

                // keep searching
                return true
            }
            
            let remaining = capacity - count
    
            // trim the fat
            if remaining > 0 {
                distancesSqrd.removeLast(remaining)
                indices.removeLast(remaining)
            }
            
            // remap to collection indices and gather our points
            for (i, treeIndex) in indices.enumerated() {
                indices[i] = tree.indices[treeIndex]
                points.append(tree.points[treeIndex])
            }
        }
    }
    
    @inlinable
    /// A fast k-nearest neighbour query. It's fast because we recycle the ``KNearest`` struct from
    /// previous queries to eliminate extra memory allocations. ``KNearest`` must not be shared
    /// with multiple threads.
    /// - Parameters:
    ///   - query: The query element.
    ///   - result: A recyclable ``KNearest`` object that contains the result of the query.
    public func nearest(to query: Element, result: inout KNearest) {
        result.reset()
        result.nearest(to: query, tree: self)
    }
    
    
    /// Slow version of k-nearest neighbours. For optimtimal performance use ``nearest(to:result:)``.
    /// - Parameters:
    ///   - k: The number of neighbours to find.
    ///   - query: The query point.
    /// - Returns: The k-nearest neighbours to the query.
    @inlinable public func nearest(k: Int, to query: Element) -> [Int] {
        var result = KNearest(k: k)
        nearest(to: query, result: &result)
        
        return result.indices
    }
}
    
