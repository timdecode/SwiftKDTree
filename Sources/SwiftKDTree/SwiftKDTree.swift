import CoreImage

public protocol KDTreeVector {
    associatedtype Component where Component : BinaryFloatingPoint
    
    static var dimensions: Int { get }
    
    static var zero: Self { get }
    
    func component(_ index: Int) -> Component
    
    subscript(_ index: Int) -> Component { get set }
    
    func distanceSquared(_ other: Self) -> Component
}

public struct StaticKDTree<Element>
where Element : KDTreeVector {
    public typealias Component = Element.Component
    
    @usableFromInline
    internal let nodes: [Node]
    
    @usableFromInline
    internal let indices: [Int]
    
    public var nodeCount: Int { return nodes.count }
    
    @usableFromInline
    enum Node {
        case leaf
        
        case node(left: Int32, value: Element, index: Int, right: Int32)
    }
    
    @usableFromInline
    init(nodes: [Node], indices: [Int]) {
        self.nodes = nodes
        self.indices = indices
    }
    
    @inlinable
    public init(points: [Element]) {
        var nodes: [Node] = []
        nodes.reserveCapacity(points.count)
        
        var indices: [Int] = .init(0..<points.count)
        var points = points

        _ = Self.build(
            values: &points,
            indices: &indices,
            nodes: &nodes,
            start: 0,
            end: points.count,
            depth: 0
        )
        
        self = .init(nodes: nodes, indices: indices)
    }
    
    @inlinable
    static func build(
        values: UnsafeMutablePointer<Element>,
        indices: UnsafeMutablePointer<Int>,
        nodes: inout [Node],
        start: Int,
        end: Int,
        depth: Int
    ) -> Int {
        guard end > start else {
            return -1
        }
        
        let count = end - start
        
        let component = depth % Element.dimensions
        
        if count == 1 {
            let index = nodes.count
            
            nodes.append( .node(left: -1, value: values[start], index: indices[start], right: -1) )
            
            return index
        } else {
            // Split along the median
            var median = start + count / 2

            // Partition the elements around the middle index
            quickSelect(targetIndex: median, values: values, indices: indices, startIndex: start, endIndex: end, component: component)
            
            // Move past duplicates
            let medianValue = values[median]
            let medianComponent = medianValue.component(component)

            while median >= 1
                    && median > start
                    // Actually, this is incorrect, this usage of .ulpOfOne does not correctly handle edge
                    // cases, there is an implementation in Swift Numerics that does this right.
                    && abs(values[median-1].component(component) - medianComponent) < Element.Component.ulpOfOne {
                median -= 1
            }
            
            // make room for our node
            let index = nodes.count
            nodes.append( .leaf )
            
            let left = build(values: values, indices: indices, nodes: &nodes, start: start, end: median, depth: depth + 1)
            
            let right = build(values: values, indices: indices, nodes: &nodes, start: median + 1, end: end, depth: depth + 1)
            
            nodes[index] = .node(left: Int32(left), value: values[median], index: indices[median], right: Int32(right))
            
            return index
        }
    }
    
    /// Quickselect function
    ///
    /// Based on https://github.com/mourner/kdbush
    ///
    /// - Parameter targetIndex: target pivot index
    /// - Parameter values: pointer to the values to be evaluated
    /// - Parameter startIndex: start index of the region of interest
    /// - Parameter endIndex: end index of the region of interest
    /// - Parameter kdDimension: dimension to evaluate
    @inlinable static func quickSelect(
        targetIndex: Int,
        values: UnsafeMutablePointer<Element>,
        indices: UnsafeMutablePointer<Int>,
        startIndex: Int,
        endIndex: Int,
        component: Int
    ) {
        
        guard endIndex - startIndex > 1 else { return }
        
        let partitionIndex = Self.partitionHoare(values, indices: indices, startIndex: startIndex, endIndex: endIndex, component: component)
        
        if partitionIndex == targetIndex {
            return
        } else if partitionIndex < targetIndex {
            let s = partitionIndex+1
            quickSelect(targetIndex: targetIndex, values: values, indices: indices, startIndex: s, endIndex: endIndex, component: component)
        } else {
            // partitionIndex is greater than the targetIndex, quickSelect moves to indexes smaller than partitionIndex
            quickSelect(targetIndex: targetIndex, values: values, indices: indices, startIndex: startIndex, endIndex: partitionIndex, component: component)
        }
    }
    
    /// # Hoare's partitioning algorithm.
    /// This is more efficient that Lomuto's algorithm.
    /// The return value is the index of the pivot element in the pointer. The left
    /// partition is [low...p-1]; the right partition is [p+1...high], where p is the
    /// return value.
    /// - - -
    /// The left partition includes all values smaller than the pivot, so
    /// if the pivot value occurs more than once, its duplicates will be found in the
    /// right partition.
    ///
    /// - Parameters:
    ///   - values: the pointer to the values
    ///   - kdDimension: the dimension sorted over
    /// - Returns: the index of the pivot element in the pointer
    @inlinable static func partitionHoare(
        _ values: UnsafeMutablePointer<Element>,
        indices: UnsafeMutablePointer<Int>,
        startIndex lo: Int,
        endIndex: Int,
        component: Int
    ) -> Int {
        let hi = endIndex - 1
        guard lo < hi else { return lo }
        
        let randomIndex = Int.random(in: lo...hi)
        values.swapAt(hi, randomIndex)
        indices.swapAt(hi, randomIndex)
        
        let kdDimensionOfPivot = values[hi].component(component)
        
        // This loop partitions the array into four (possibly empty) regions:
        //   [lo   ...    i] contains all values < pivot,
        //   [i+1  ...  j-1] are values we haven't looked at yet,
        //   [j    ..< hi-1] contains all values >= pivot,
        //   [hi           ] is the pivot value.
        var i = lo
        var j = hi - 1
        
        while true {
            while values[i].component(component) < kdDimensionOfPivot {
                i += 1
            }
            while lo < j && values[j].component(component) >= kdDimensionOfPivot {
                j -= 1
            }
            guard i < j else {
                break
            }
            
            values.swapAt(i, j)
            indices.swapAt(i, j)
        }
        
        // Swap the pivot element with the first element that is >=
        // the pivot. Now the pivot sits between the < and >= regions and the
        // array is properly partitioned.
        values.swapAt(i, hi)
        indices.swapAt(i, hi)
        
        return i
    }
    
}

internal extension UnsafeMutablePointer {
    @_transparent
    @inlinable func swapAt(_ i: Int, _ j: Int) {
        let temp = self[i]
        self[i] = self[j]
        self[j] = temp
    }
}





public struct SwiftKDTree {
    public private(set) var text = "Hello, World!"
    
    public init() {
    }
}
