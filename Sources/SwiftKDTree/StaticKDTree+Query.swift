//
//  File.swift
//  
//
//  Created by Timothy Davison on 2021-11-01.
//

import Foundation

extension StaticKDTree {
    public func points(within radius: Element.Component, of query: Element) -> [Element] {
        guard !nodes.isEmpty else { return [] }
        
        var result: [Element] = []
        
        points(within: radius, of: query, node: nodes.first!, points: &result)
        
        return result
    }
    
    private func points(within radius: Element.Component, of query: Element, node: Node, points: inout [Element]) {
        switch node {
        case .leaf: return
        case let .node(left, value, k, right):
            let delta = value.component(k) - query.component(k)
            
            let (nearest, other) = delta > 0 ? (left, right) : (right, left)
            
            // check the best estimate (the closer subTree)
            if nearest >= 0 {
                self.points(within: radius, of: query, node:  nodes[Int(nearest)], points: &points)
            }
            
            // if the search radius intersects the hyperplane of this tree node
            // there could be points in the other subtree
            if abs(delta) < radius {
                if value.distanceSquared(query) <= radius * radius {
                    points.append(value)
                }
                
                if other >= 0 {
                    self.points(within: radius, of: query, node: nodes[Int(other)], points: &points)
                }
            }
            
            break
        }
    }

    struct Query {
        let tree: StaticKDTree
        let k: Int
    }
}
