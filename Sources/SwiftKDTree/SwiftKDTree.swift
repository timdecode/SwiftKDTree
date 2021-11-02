import CoreImage

public protocol Vector {
    associatedtype Component where Component : FloatingPoint
    
    static var dimensions: Int { get }
    
    func component(_ index: Int) -> Component
    func distance(_ other: Self) -> Float
}

public struct StaticKDTree<Element>
where Element : Vector {
    private var nodes: ContiguousArray<Node<Element>>

    public var nodeCount: Int { return nodes.count }
    
    public init(points: [Element]) {
        self.nodes = []
        
        var points = points
        
        points.withUnsafeMutableBufferPointer { buffer in
            Self.build(values: buffer, depth: 0, tree: &self)
        }
    }
    
    private static func build( values: UnsafeMutableBufferPointer<Element>, depth: Int, tree: inout Self ) {
        // leaf
        if values.count == 1 {
            tree.nodes.append( .leaf )
        } else {
            // Split along the median
            var median: Int = values.count / 2
            
            let component = depth % Element.dimensions

            // Partition the elements around the middle index
            quickSelect(targetIndex: median, values: values, component: component)
            
            // Move past duplicates
            let medianValue = values[median]
            let medianComponent = medianValue.component(component)
            while median >= 1 && median > 0 && abs(values[median-1].component(component) - medianComponent) < Element.Component.ulpOfOne {
                median -= 1
            }
            
            let left = Int32(tree.nodes.count)
            build(values: .init(rebasing: values.prefix(upTo: median)), depth: depth + 1, tree: &tree)
            
            let right = Int32(tree.nodes.count)
            build(values: .init(rebasing: values.suffix(from: median)), depth: depth + 1, tree: &tree)
            
            tree.nodes.append( .node(left: left, value: medianValue, right: right))
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
    private static func quickSelect(targetIndex: Int, values: UnsafeMutableBufferPointer<Element>, component: Int) {
        guard values.count > 0 else { return }
        
        let partitionIndex = Self.partitionHoare(values, component: component)
        
        if partitionIndex == targetIndex {
            return
        } else if partitionIndex < targetIndex {
            let s = partitionIndex+1
            quickSelect(targetIndex: targetIndex, values: .init(rebasing: values.suffix(from: s)), component: component)
//            quickSelect(targetIndex: targetIndex, values: values, startIndex: s, endIndex: endIndex, component: component)
        } else {
            // partitionIndex is greater than the targetIndex, quickSelect moves to indexes smaller than partitionIndex
            quickSelect(targetIndex: targetIndex, values: .init(rebasing: values.prefix(upTo: partitionIndex)), component: component)
//            quickSelect(targetIndex: targetIndex, values: values, startIndex: startIndex, endIndex: partitionIndex, component: component)
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
    private static func partitionHoare(_ values: UnsafeMutableBufferPointer<Element>, component: Int) -> Int {
        let hi = values.count - 1
        guard values.count > 0 else { return 0 }
        
        let randomIndex = Int.random(in: 0...hi)
        values.swapAt(hi, randomIndex)
        
        let kdDimensionOfPivot = values[hi].component(component)
        
        // This loop partitions the array into four (possibly empty) regions:
        //   [lo   ...    i] contains all values < pivot,
        //   [i+1  ...  j-1] are values we haven't looked at yet,
        //   [j    ..< hi-1] contains all values >= pivot,
        //   [hi           ] is the pivot value.
        var i = 0
        var j = hi - 1
        
        while true {
            while values[i].component(component) < kdDimensionOfPivot {
                i += 1
            }
            while 0 < j && values[j].component(component) >= kdDimensionOfPivot {
                j -= 1
            }
            guard i < j else {
                break
            }
            values.swapAt(i, j)
        }
        
        // Swap the pivot element with the first element that is >=
        // the pivot. Now the pivot sits between the < and >= regions and the
        // array is properly partitioned.
        values.swapAt(i, hi)
        return i
    }
    
}

fileprivate extension UnsafeMutablePointer {
    @_transparent
    func swapAt(_ i: Int, _ j: Int) {
        let temp = self[i]
        self[i] = self[j]
        self[j] = temp
    }
}

enum Node<Element> {
    case leaf
    
    case node(left: Int32, value: Element, right: Int32)
}



public struct SwiftKDTree {
    public private(set) var text = "Hello, World!"
    
    public init() {
    }
}
