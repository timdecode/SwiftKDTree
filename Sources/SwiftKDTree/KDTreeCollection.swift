//
//  File.swift
//  
//
//  Created by Timothy Davison on 2021-11-09.
//

import Foundation

struct AABB<KDTreeVector> {
    var min: KDTreeVector
    var max: KDTreeVector
    
    init(min: KDTreeVector, max: KDTreeVector) {
        self.min = min
        self.max = max
    }
}

/// A Swift port of nanoflann.
struct KDTreeCollection<Element>
where Element : KDTreeVector {
    public typealias Component = Element.Component
    
    @usableFromInline
    internal let nodes: [Node]
    
    @usableFromInline
    internal let indices: [Int]
    
    let maxLeafSize: Int
    let dimensions: Int
    
    @usableFromInline
    enum Node {
        /// Indices of points in a leaf node
        case leaf(start: Int, end: Int)
        
        /// Dimension of subdivision and the values of subdivision.
        case node(child1: Int, child2: Int, dimension: Int, low: Float, hight: Float)
    }
    
    static func divideTree(nodes: inout [Node], left: Int, right: Int, bounds: inout AABB) -> Int {
        return 0
    }
}
