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
    let maxLeafSize: Int
    
    @usableFromInline
    enum Node {
        /// Indices of points in a leaf node
        case leaf(start: Int, end: Int)
        
        /// Dimension of subdivision and the values of subdivision.
        case node(child1: Int, child2: Int, dimension: Int, min: Component, max: Component)
        
        case unitilized
    }
    
    @inlinable
    public init(points: [Element], maxLeafSize: Int) {
        self.maxLeafSize = maxLeafSize
        self.indices = []
        
        guard points.count > 0 else {
            self.nodes = []
            
            return
        }
        
        var nodes: [Node] = []
        nodes.reserveCapacity(points.count)

        var points: [Element] = points
        
        var bounds: AABB<Element> = points.reduce(into: .init(min: points[0], max:points[0])) { partialResult, vec in
            partialResult.append(vec)
        }
        
        _ = Self.divideTree(nodes: &nodes, dataset: &points, left: 0, right: points.count, bounds: &bounds, maxLeafSize: maxLeafSize)
        
        self.nodes = nodes
    }
    
    @inlinable
    static func divideTree(
        nodes: inout [Node],
        dataset: UnsafeMutablePointer<Element>,
        left: Int,
        right: Int,
        bounds: inout AABB<Element>,
        maxLeafSize: Int
    ) -> Int {
        let index = nodes.count
        
        // If too few exemplars remain, then make this a leaf node.
        if (right - left) <= maxLeafSize {
            nodes.append( .leaf(start: left, end: right) )
            
            // compute bounding-box of leaf points
            bounds = .init(min: dataset[left], max: dataset[left])
            for k in (left + 1)..<right {
                bounds.append(dataset[k])
            }
        } else {
            let (idx, cutFeature, cutValue) = middleSplit(
                dataset: dataset,
                ind: left,
                count: right - left,
                bounds: bounds
            )
            
            nodes.append( .unitilized )
            
            var leftBounds = bounds
            leftBounds.max[cutFeature] = cutValue
            let child1 = divideTree(
                nodes: &nodes,
                dataset: dataset,
                left: left,
                right: left + idx,
                bounds: &leftBounds,
                maxLeafSize: maxLeafSize
            )
            
            var rightBounds = bounds
            rightBounds.min[cutFeature] = cutValue
            let child2 = divideTree(
                nodes: &nodes,
                dataset: dataset,
                left: left + idx,
                right: right,
                bounds: &rightBounds,
                maxLeafSize: maxLeafSize
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
        ind: Int,
        count: Int,
        bounds: AABB<Element>
    ) -> (index: Int, cutFeature: Int, cutValue: Component) {
        let EPS: Component = 0.00001
        
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
            let (lim1, lim2) = planeSplit(dataset: dataset, ind: ind, count: count, cutFeature: cutFeature, cutValue: cutValue)

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
            left += 1
            right -= 1
        }
        
        // If either list is empty, it means that all remaining features
        // are identical. Split in the middle to maintain a balanced tree.
        var lim1 = left
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
}
