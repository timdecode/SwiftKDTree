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
    
    public func nearestK(
        _ k: Int,
        to query: Element,
        result: inout [(distance: Component, point: Element)],
        condition: (Element) -> Bool = { _ in true }
    ) {
        result.removeAll(keepingCapacity: true)
        
        guard !nodes.isEmpty else { return }
        
        var kNearest = KNearest(k: k)
        kNearest.nearest(to: query, of: self, node: nodes.first!, depth: 0, nearestValues: &result)        
    }

    struct KNearest {
        public typealias ElementPair = (distance: Component, point: Element)

        @usableFromInline let goalNumber: Int
        @usableFromInline var currentSize = 0
        @usableFromInline var full: Bool = false
        @usableFromInline var biggestDistance: Component = Component.infinity
        
        init(k: Int) {
            self.goalNumber = k
        }
        
        @inlinable mutating func nearest(
            to query: Element,
            of tree: StaticKDTree,
            node: StaticKDTree.Node,
            depth: Int,
            nearestValues: inout [ElementPair],
            where condition: (Element) -> Bool = { _ in true }
        ) {
            let dim = depth % Element.dimensions
            
            switch node {
            case let .node(left, value, right):
                let dimensionDifference = value.component(dim) - query.component(dim)
                let isLeftOfValue = dimensionDifference > 0
                
                //check the best estimate side
                let closerSubtree = isLeftOfValue ? left : right
                
                if closerSubtree >= 0 {
                    nearest(
                        to: query,
                        of: tree,
                        node: tree.nodes[Int(closerSubtree)],
                        depth: depth + 1,
                        nearestValues: &nearestValues, where: condition
                    )
                }

                if condition(value) {
                    //check the nodes value
                    let currentDistance = value.distanceSquared(query)
                    self.append(value, distance: currentDistance, nearestValues: &nearestValues)
                }

                //if the bestDistance so far intersects the hyperplane at the other side of this value
                //there could be points in the other subtree
                if dimensionDifference*dimensionDifference < biggestDistance || !full {
                    let otherSubtree = isLeftOfValue ? right : left
                    
                    if otherSubtree > 0 {
                        nearest(
                            to: query,
                            of: tree,
                            node: tree.nodes[Int(otherSubtree)],
                            depth: depth + 1,
                            nearestValues: &nearestValues,
                            where: condition
                        )
                    }
                }
            case .leaf: break
            }
        }
        
        @inlinable mutating func append(_ value: Element, distance: Component, nearestValues: inout [ElementPair]) {
            guard !full || distance < biggestDistance else { return }

            if let index = nearestValues.firstIndex(where: { return distance < $0.distance }) {
                nearestValues.insert(ElementPair(distance: distance, point: value), at: index)
                if full {
                    nearestValues.removeLast()
                    biggestDistance = nearestValues.last!.distance
                }
                else {
                    currentSize += 1
                    full = currentSize >= goalNumber
                }
            }
            else {
                //not full so we append at the end
                nearestValues.append(ElementPair(distance: distance, point: value))
                currentSize += 1
                full = currentSize >= goalNumber
                biggestDistance = distance
            }
        }
    }
}


