import CoreGraphics
import Foundation

public struct TreemapNode: Identifiable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var size: Int64
    public var categoryID: String?
    public var rect: CGRect
    public var children: [TreemapNode]

    public init(
        id: String,
        name: String,
        size: Int64,
        categoryID: String? = nil,
        rect: CGRect = .zero,
        children: [TreemapNode] = []
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.categoryID = categoryID
        self.rect = rect
        self.children = children
    }

    /// Computes a normalized slice-and-dice / squarified layout within `bounds` (default [0, 0, 1, 1]).
    public static func layout(categories: [CleanCategory], bounds: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) -> TreemapNode {
        let activeCategories = categories.filter { $0.bytes > 0 }
        let totalSize = activeCategories.reduce(0) { $0 + $1.bytes }
        
        guard totalSize > 0 else {
            return TreemapNode(
                id: "root",
                name: "Total Reclaimable",
                size: 0,
                rect: bounds,
                children: []
            )
        }

        var nodes = activeCategories.map { cat in
            TreemapNode(
                id: cat.id,
                name: cat.name,
                size: cat.bytes,
                categoryID: cat.id,
                rect: .zero,
                children: []
            )
        }

        // Layout children proportionally along the major axis
        nodes = layoutSliceAndDice(nodes: nodes, in: bounds, totalSize: totalSize)

        return TreemapNode(
            id: "root",
            name: "Total Reclaimable",
            size: totalSize,
            rect: bounds,
            children: nodes
        )
    }

    /// Computes layout for disk analyzer directory entries.
    public static func layout(
        entries: [AnalyzeEntry],
        rootPath: String,
        bounds: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    ) -> TreemapNode {
        let activeEntries = entries.filter { $0.size > 0 }
        let totalSize = activeEntries.reduce(0) { $0 + $1.size }
        let rootName = (rootPath as NSString).lastPathComponent

        guard totalSize > 0 else {
            return TreemapNode(
                id: rootPath,
                name: rootName.isEmpty ? "/" : rootName,
                size: 0,
                rect: bounds,
                children: []
            )
        }

        var nodes = activeEntries.map { entry in
            TreemapNode(
                id: entry.path,
                name: entry.name,
                size: entry.size,
                categoryID: entry.isDir ? "directory" : "file",
                rect: .zero,
                children: []
            )
        }

        nodes = layoutSliceAndDice(nodes: nodes, in: bounds, totalSize: totalSize)

        return TreemapNode(
            id: rootPath,
            name: rootName.isEmpty ? "/" : rootName,
            size: totalSize,
            rect: bounds,
            children: nodes
        )
    }

    private static func layoutSliceAndDice(
        nodes: [TreemapNode],
        in rect: CGRect,
        totalSize: Int64
    ) -> [TreemapNode] {
        guard !nodes.isEmpty, totalSize > 0 else { return [] }
        guard nodes.count > 1 else {
            var single = nodes[0]
            single.rect = rect
            return [single]
        }

        // Split nodes into two roughly equal halves
        let halfSize = totalSize / 2
        var runningSum: Int64 = 0
        var splitIndex = 0

        for (index, node) in nodes.enumerated() {
            runningSum += node.size
            if runningSum >= halfSize || index == nodes.count - 1 {
                splitIndex = max(1, index)
                break
            }
        }

        let firstHalf = Array(nodes[0..<splitIndex])
        let secondHalf = Array(nodes[splitIndex...])

        let firstHalfSize = firstHalf.reduce(0) { $0 + $1.size }
        let secondHalfSize = secondHalf.reduce(0) { $0 + $1.size }

        let firstRatio = CGFloat(firstHalfSize) / CGFloat(totalSize)

        var rect1: CGRect
        var rect2: CGRect

        if rect.width >= rect.height {
            // Split vertically (along width)
            let width1 = rect.width * firstRatio
            let width2 = rect.width - width1
            rect1 = CGRect(x: rect.minX, y: rect.minY, width: width1, height: rect.height)
            rect2 = CGRect(x: rect.minX + width1, y: rect.minY, width: width2, height: rect.height)
        } else {
            // Split horizontally (along height)
            let height1 = rect.height * firstRatio
            let height2 = rect.height - height1
            rect1 = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: height1)
            rect2 = CGRect(x: rect.minX, y: rect.minY + height1, width: rect.width, height: height2)
        }

        let laidOutFirst = layoutSliceAndDice(nodes: firstHalf, in: rect1, totalSize: firstHalfSize)
        let laidOutSecond = layoutSliceAndDice(nodes: secondHalf, in: rect2, totalSize: secondHalfSize)

        return laidOutFirst + laidOutSecond
    }
}
