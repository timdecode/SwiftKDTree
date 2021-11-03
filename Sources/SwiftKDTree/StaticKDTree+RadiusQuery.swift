//
//  StaticKDTree+RadiusQuery.swift
//  
//
//  Created by Timothy Davison on 2021-11-02.
//

import Foundation

extension StaticKDTree {
    public func points(
        within radius: Element.Component,
        of query: Element,
        condition: (Element) -> Bool = { _ in true }
    ) -> [Element] {
        guard !nodes.isEmpty else { return [] }
        
        var result: [Element] = []
        
        points(within: radius, of: query, node: nodes.first!, depth: 0) {
            if condition($0) {
                result.append($0)
            }
        }
        
        return result
    }
    
    public func points(
        within radius: Element.Component,
        of query: Element,
        result: (Element) -> ()
    ) {
        points(within: radius, of: query, node: nodes.first!, depth: 0, result: result)
    }

    
    @inlinable internal func points(
        within radius: Element.Component,
        of query: Element,
        node: Node,
        depth: Int,
        result: (Element) ->  ()
    ) {
        switch node {
        case .leaf: return
        case let .node(left, value, right):
            let k = depth % Element.dimensions
            
            let delta = value.component(k) - query.component(k)
            
            let (nearest, other) = delta > 0 ? (left, right) : (right, left)
            
            // check the best estimate (the closer subTree)
            if nearest >= 0 {
                self.points(within: radius, of: query, node:  nodes[Int(nearest)], depth: depth + 1, result: result)
            }
            
            // if the search radius intersects the hyperplane of this tree node
            // there could be points in the other subtree
            if abs(delta) < radius {
                if value.distanceSquared(query) <= radius * radius {
                    result(value)
                }
                
                if other >= 0 {
                    self.points(within: radius, of: query, node: nodes[Int(other)], depth: depth + 1, result: result)
                }
            }
            
            break
        }
    }
}
