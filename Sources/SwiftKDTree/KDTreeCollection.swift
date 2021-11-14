//
//  File.swift
//  
//
//  Created by Timothy Davison on 2021-11-09.
//

import Foundation

@usableFromInline
struct AABB<Vector : KDTreeVector> {
    @usableFromInline
    var min: Vector
    
    @usableFromInline
    var max: Vector
    
    @inlinable
    init(min: Vector, max: Vector) {
        self.min = min
        self.max = max
    }
    
    @inlinable
    mutating func append(_ point: Vector) {
        for i in 0..<Vector.dimensions {
            self.min[i] = Swift.min(self.min[i], point[i])
            self.max[i] = Swift.max(self.max[i], point[i])
        }
    }
    
    @inlinable
    var maxSpan: Vector.Component {
        var maxSpan = max[0] - min[0]
        
        for i in 1..<Vector.dimensions {
            maxSpan = Swift.max(maxSpan, max[i] - min[i])
        }
        
        return maxSpan
    }
}

/// A Swift port of nanoflann.
public struct KDTreeCollection<Element>
where Element : KDTreeVector {
    public typealias Component = Element.Component
    
    @usableFromInline
    internal let nodes: [Node]
    
    @usableFromInline
    internal let indices: [Int]
    
    @usableFromInline
    internal let points: [Element]
    
    @usableFromInline
    let maxLeafSize: Int

    @usableFromInline
    let bounds: AABB<Element>

    public let EPS: Component
    
    @usableFromInline
    enum Node {
        /// Indices of points in a leaf node
        case leaf(start: Int, end: Int)
        
        /// Dimension of subdivision and the values of subdivision.
        case node(child1: Int, child2: Int, dimension: Int, min: Component, max: Component)
        
        case unitilized
    }
    
    @inlinable
    public init(points: [Element], maxLeafSize: Int, EPS: Component = 0.00001) {
        guard points.count > 0 else {
            self.nodes = []
            self.points = []
            self.indices = []
            self.maxLeafSize = maxLeafSize
            self.EPS = EPS
            self.bounds = .init(min: .zero, max: .zero)
            
            return
        }
        
        self.maxLeafSize = maxLeafSize
        self.EPS = EPS
        
        var nodes: [Node] = []
        nodes.reserveCapacity(points.count)
        
        var indices: [Int] = .init(0..<points.count)

        var points: [Element] = points
        
        var bounds: AABB<Element> = points.reduce(into: .init(min: points[0], max:points[0])) { partialResult, vec in
            partialResult.append(vec)
        }
        
        _ = Self.divideTree(
            nodes: &nodes,
            dataset: &points,
            dataIndices: &indices,
            left: 0,
            right: points.count,
            bounds: &bounds,
            maxLeafSize: maxLeafSize,
            EPS: EPS
        )
        
        self.nodes = nodes
        self.points = points
        self.indices = indices
        self.bounds = bounds
    }
    
    @inlinable
    static func divideTree(
        nodes: inout [Node],
        dataset: UnsafeMutablePointer<Element>,
        dataIndices: UnsafeMutablePointer<Int>,
        left: Int,
        right: Int,
        bounds: inout AABB<Element>,
        maxLeafSize: Int,
        EPS: Component
    ) -> Int {
        let index = nodes.count
        
        // If too few exemplars remain, then make this a leaf node.
        if (right - left) <= maxLeafSize {
            nodes.append( .leaf(start: left, end: right) )
            
            // compute bounding-box of leaf points
            bounds = .init(min: dataset[left], max: dataset[left])
            
            if left < right {
                for k in (left + 1)..<right {
                    bounds.append(dataset[k])
                }
            }
        } else {
            let (idx, cutFeature, cutValue) = middleSplit(
                dataset: dataset,
                dataIndices: dataIndices,
                ind: left,
                count: right - left,
                bounds: bounds,
                EPS: EPS
            )
            
            nodes.append( .unitilized )
            
            var leftBounds = bounds
            leftBounds.max[cutFeature] = cutValue
            let child1 = divideTree(
                nodes: &nodes,
                dataset: dataset,
                dataIndices: dataIndices,
                left: left,
                right: left + idx,
                bounds: &leftBounds,
                maxLeafSize: maxLeafSize,
                EPS: EPS
            )
            
            var rightBounds = bounds
            rightBounds.min[cutFeature] = cutValue
            let child2 = divideTree(
                nodes: &nodes,
                dataset: dataset,
                dataIndices: dataIndices,
                left: left + idx,
                right: right,
                bounds: &rightBounds,
                maxLeafSize: maxLeafSize,
                EPS: EPS
            )
            
            nodes[index] = .node(
                child1: child1,
                child2: child2,
                dimension: cutFeature,
                min: leftBounds.max[cutFeature],
                max: rightBounds.min[cutFeature]
            )
        }
        
        return index
    }
    
    @inlinable
    static func middleSplit(
        dataset: UnsafeMutablePointer<Element>,
        dataIndices: UnsafeMutablePointer<Int>,
        ind: Int,
        count: Int,
        bounds: AABB<Element>,
        EPS: Component
    ) -> (index: Int, cutFeature: Int, cutValue: Component) {
        
        let maxSpan = bounds.maxSpan
        
        var maxSpread = Component(-1)
        
        var cutFeature = 0
        
        for i in 0..<Element.dimensions {
            let span = bounds.max[i] - bounds.min[i]
            
            if span > (1.0 - EPS) * maxSpan {
                let (minElement, maxElement) = computeMinMax(dataset: dataset, ind: ind, count: count, element: i)
                
                let spread = maxElement - minElement
                
                if spread > maxSpread {
                    cutFeature = i
                    maxSpread = spread
                }
            }
        }
        
        // Split in the middle
        let cutValue: Component = {
            let splitValue: Component = (bounds.min[cutFeature] + bounds.max[cutFeature]) / 2.0
            
            let (minElement, maxElement) = computeMinMax(dataset: dataset, ind: ind, count: count, element: cutFeature)

            if splitValue < minElement {
                return minElement
            } else if splitValue > maxElement {
                return maxElement
            } else {
                return splitValue
            }
        }()
        
        
        let index: Int = {
            let (lim1, lim2) = planeSplit(dataset: dataset, dataIndices: dataIndices, ind: ind, count: count, cutFeature: cutFeature, cutValue: cutValue)

            if lim1 > count / 2 {
                return lim1
            } else if lim2 < count / 2 {
                return lim2
            } else {
                return count / 2
            }
        }()
        
        return (index, cutFeature, cutValue)
    }
    
    @inlinable
    static func planeSplit(
        dataset: UnsafeMutablePointer<Element>,
        dataIndices: UnsafeMutablePointer<Int>,
        ind: Int,
        count: Int,
        cutFeature: Int,
        cutValue: Component
    ) -> (lim1: Int, lim2: Int) {
        var left = 0
        var right = count - 1
        
        // Move vector indices for left subtree to front of list.
        while true {
            while left <= right && dataset[ind + left][cutFeature] < cutValue {
                left += 1
            }
            
            while right > 0 && left <= right && dataset[ind + right][cutFeature] >= cutValue {
                right -= 1
            }
            
            if left > right || right == 0 {
                break
            }
            
            dataset.swapAt(ind + left, ind + right)
            dataIndices.swapAt(ind + left, ind + right)

            left += 1
            right -= 1
        }
        
        // If either list is empty, it means that all remaining features
        // are identical. Split in the middle to maintain a balanced tree.
        let lim1 = left
        right = count - 1
        while true {
            while left <= right && dataset[ind + left][cutFeature] <= cutValue {
                left += 1
            }
            
            while right > 0 && left <= right && dataset[ind + right][cutFeature] > cutValue {
                right -= 1
            }
            
            if left > right || right == 0 {
                break
            }
            
            dataset.swapAt(ind + left, ind + right)
            dataIndices.swapAt(ind + left, ind + right)
            
            left += 1
            right -= 1
        }
        
        return (lim1, left)
    }
    
    @inlinable
    static func computeMinMax(
        dataset: UnsafeMutablePointer<Element>,
        ind: Int,
        count: Int,
        element: Int
    ) -> (min: Component, max: Component) {
        var minElement = dataset[ind][element]
        var maxElement = minElement
        
        for i in 1..<count {
            let value = dataset[ind + i][element]
            
            if value < minElement {
                minElement = value
            }
            
            if value > minElement {
                maxElement = value
            }
        }
        
        return (minElement, maxElement)
    }
    
    @inlinable public func points(
        within radius: Component,
        of query: Element
    ) -> [(Int, Element)] {
        var result: [(Int, Element)] = []
        
        let radiusSqrd = radius * radius
        
        if nodes.isEmpty { return [] }

        search(query: query, wordDistance: {radiusSqrd}) { i, distSqrd in
            if distSqrd < radiusSqrd {
                result.append((indices[i], points[i]))
            }

            return true
        }
        
        return result
    }
    
    @inlinable public func points(
        within radius: Component,
        of query: Element,
        result: (Int, Element) -> (Bool)
    ) {
        if nodes.isEmpty { return }
        
        let radiusSqrd = radius * radius

        search(query: query, wordDistance: {radiusSqrd}) { i, distSqrd in
            if distSqrd < radiusSqrd {
                return result(indices[i], points[i])
            }
            
            return true
        }
    }
    
    @inlinable func initialDistance(query: Element) -> (distanceSqrd: Component, distanceVector: Element) {
        var distanceSqrd: Component = 0.0
        var distanceVector: Element = .zero
        
        for i in 0..<Element.dimensions {
            if query[i] < bounds.min[i] {
                let d = (query[i] - bounds.min[i])
                distanceVector[i] = d * d
                distanceSqrd += distanceVector[i]
            }
            
            if query[i] > bounds.max[i] {
                let d = query[i] - bounds.max[i]
                
                distanceVector[i] = d * d
                distanceSqrd += distanceVector[i]
            }
        }
        
        return (distanceSqrd, distanceVector)
    }
    
    @inlinable
    func search(query: Element, wordDistance: () -> Component, result: (Int, Component) -> (Bool)) {
        var (distanceSqrd, distanceVector) = initialDistance(query: query)
        
        _ = _searchLevel(
            query: query,
            node: 0,
            minDistanceSqrd: distanceSqrd,
            distanceVector: &distanceVector,
            worstDistance: wordDistance,
            epsError: self.EPS,
            result: result
        )
    }
    
    /// Searches the tree. Use ``initialDistance(query)`` to initialize the ``distanceVector`` and ``minDistanceSqrd`` parameters.
    /// - Parameters:
    ///   - query: The query point.
    ///   - nodeIndex: The node to search from.
    ///   - minDistanceSqrd: The current min squared distance of the search.
    ///   - distanceVector: The accumulated minimum distance vector.
    ///   - worstDistance: The worst distance in the result (you could pass a constant vector if you wish).
    ///   - epsError: The smallest error to allow in comparisons.
    ///   - result: A result call back. Return false from this callback to exit the search. The first paramer is an index into ``points`` and ``indices``.
    ///   The second parameter is the squared distance.
    /// - Returns: Whether we should stop searching.
    @inlinable func _searchLevel(
        query: Element,
        node nodeIndex: Int,
        minDistanceSqrd: Component,
        distanceVector: inout Element,
        worstDistance: () -> Component,
        epsError: Component,
        result: (Int, Component) -> (Bool)
    ) -> Bool {
        let node = nodes[nodeIndex]
        
        switch node {
        case let .leaf(start: start, end: end):
            for i in start..<end {
                let dist = query.distanceSquared(points[i])
                
                if dist < worstDistance() && !result(i, dist) {
                    // The result doesn't want anything more, we're done
                    return false
                }
            }

            // Keep searching
            return true
            
        case let .node(child1: child1, child2: child2, dimension: d, min: divMin, max: divMax):
            // Which branch to take first?
            let val = query[d]
            
            let diff1 = val - divMin
            let diff2 = val - divMax
            
            let (bestChild, otherChild, cutDist) = { () -> (Int, Int, Component) in
                if (diff1 + diff2) < 0 {
                    let cutDist = (val - divMax) * (val - divMax)
                    
                    return (child1, child2, cutDist)
                } else {
                    let cutDist = (val - divMin) * (val - divMin)
                    
                    return (child2, child1, cutDist)
                }
            }()
            
            // Recurse the best child
            if !_searchLevel(
                query: query,
                node: bestChild,
                minDistanceSqrd: minDistanceSqrd,
                distanceVector: &distanceVector,
                worstDistance: worstDistance,
                epsError: epsError,
                result: result
            ) { return false }
            
            
            // Are we within a certain radius to search the other child?
            let distance = distanceVector[d]
            let minDistanceSqrd = minDistanceSqrd + cutDist - distance
            
            if minDistanceSqrd * epsError <= worstDistance() {
                if !_searchLevel(
                    query: query,
                    node: otherChild,
                    minDistanceSqrd: minDistanceSqrd,
                    distanceVector: &distanceVector,
                    worstDistance: worstDistance,
                    epsError: epsError,
                    result: result
                ) { return false }
            }
            
            distanceVector[d] = distance
            
            return true
        case .unitilized: fatalError()
            
        }
    }
}
