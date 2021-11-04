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
        of query: Element
    ) -> [(Element, Int)] {
        guard !nodes.isEmpty else { return [] }
        
        var result: [(Element, Int)] = []
        
        points(within: radius, of: query, node: nodes.first!, depth: 0) { (e, i) in
            result.append((e, i))
        }
        
        return result
    }
    
    public func points(
        within radius: Element.Component,
        of query: Element,
        result: (Element, Int) -> ()
    ) {
        points(within: radius, of: query, node: nodes.first!, depth: 0, result: result)
    }

    
    @inlinable internal func points(
        within radius: Element.Component,
        of query: Element,
        node: Node,
        depth: Int,
        result: (Element, Int) ->  ()
    ) {
        switch node {
        case .leaf: return
        case let .node(left, value, index, right):
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
                    result(value, index)
                }
                
                if other >= 0 {
                    self.points(within: radius, of: query, node: nodes[Int(other)], depth: depth + 1, result: result)
                }
            }
            
            break
        }
    }
}
