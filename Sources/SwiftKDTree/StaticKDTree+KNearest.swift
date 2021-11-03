//
//  File.swift
//  
//
//  Created by Timothy Davison on 2021-11-01.
//

import Foundation

extension StaticKDTree {
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


