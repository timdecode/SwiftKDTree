//
//  File.swift
//  
//
//  Created by Timothy Davison on 2021-11-02.
//

import Foundation

extension StaticKDTree {
    public func points(within radius: Element.Component, of query: Element) -> [Element] {
        guard !nodes.isEmpty else { return [] }
        
        var result: [Element] = []
        
        points(within: radius, of: query, node: nodes.first!, depth: 0, points: &result)
        
        return result
    }
    
    private func points(within radius: Element.Component, of query: Element, node: Node, depth: Int, points: inout [Element]) {
        switch node {
        case .leaf: return
        case let .node(left, value, right):
            let k = depth % Element.dimensions
            
            let delta = value.component(k) - query.component(k)
            
            let (nearest, other) = delta > 0 ? (left, right) : (right, left)
            
            // check the best estimate (the closer subTree)
            if nearest >= 0 {
                self.points(within: radius, of: query, node:  nodes[Int(nearest)], depth: depth + 1, points: &points)
            }
            
            // if the search radius intersects the hyperplane of this tree node
            // there could be points in the other subtree
            if abs(delta) < radius {
                if value.distanceSquared(query) <= radius * radius {
                    points.append(value)
                }
                
                if other >= 0 {
                    self.points(within: radius, of: query, node: nodes[Int(other)], depth: depth + 1, points: &points)
                }
            }
            
            break
        }
    }
}
