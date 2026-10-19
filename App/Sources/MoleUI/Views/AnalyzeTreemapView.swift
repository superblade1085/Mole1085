import SwiftUI
import MoleEngine

public struct AnalyzeTreemapView: View {
    @Bindable public var coordinator: MoleCoordinator
    @State private var hoveredNodeID: String? = nil

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    private var activeRoot: TreemapNode? {
        coordinator.diskAnalyzerRoot ?? coordinator.treemapRoot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            if let root = activeRoot, !root.children.isEmpty {
                treemapCanvas(root: root)
            } else {
                emptyStateView
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 450)
        .task {
            if coordinator.diskAnalyzerRoot == nil && !coordinator.isAnalyzingDisk {
                try? await coordinator.analyzeDiskUsage(path: coordinator.analyzedPath)
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Disk Space Treemap")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Interactive proportional visualization powered by Mole CLI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if coordinator.isAnalyzingDisk || coordinator.isScanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task {
                            try? await coordinator.analyzeDiskUsage(path: coordinator.analyzedPath)
                        }
                    } label: {
                        Label("Re-scan", systemImage: "arrow.clockwise")
                    }
                    .help("Re-analyze current directory")
                }
            }

            // Interactive Navigation & Breadcrumbs Bar
            HStack(spacing: 8) {
                // Back / Up directory button
                Button {
                    let parent = (coordinator.analyzedPath as NSString).deletingLastPathComponent
                    if !parent.isEmpty && parent != coordinator.analyzedPath {
                        Task {
                            try? await coordinator.analyzeDiskUsage(path: parent)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .disabled(coordinator.analyzedPath == "/" || coordinator.isAnalyzingDisk)
                .help("Navigate to parent directory")

                // Breadcrumb path components
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(displayPath(coordinator.analyzedPath))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if let hovered = hoveredNodeID, let node = activeRoot?.children.first(where: { $0.id == hovered }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(node.name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(GlassTheme.warmAmber)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .clipShape(Capsule())

                Spacer()

                // Quick jump destinations
                HStack(spacing: 6) {
                    quickJumpButton(label: "Home", path: NSHomeDirectory(), icon: "house")
                    quickJumpButton(label: "Caches", path: NSHomeDirectory() + "/Library/Caches", icon: "archivebox")
                    quickJumpButton(label: "Developer", path: NSHomeDirectory() + "/Library/Developer", icon: "hammer")
                }
            }
        }
    }

    private func displayPath(_ raw: String) -> String {
        let home = NSHomeDirectory()
        if raw.hasPrefix(home) {
            return "~" + raw.dropFirst(home.count)
        }
        return raw.isEmpty ? "/" : raw
    }

    private func quickJumpButton(label: String, path: String, icon: String) -> some View {
        Button {
            Task {
                try? await coordinator.analyzeDiskUsage(path: path)
            }
        } label: {
            Label(label, systemImage: icon)
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(coordinator.analyzedPath == path || coordinator.isAnalyzingDisk)
        .help("Analyze \(label)")
    }

    private func treemapCanvas(root: TreemapNode) -> some View {
        GeometryReader { geometry in
            let canvasWidth = geometry.size.width
            let canvasHeight = geometry.size.height

            ZStack(alignment: .topLeading) {
                ForEach(root.children) { node in
                    let rect = CGRect(
                        x: node.rect.minX * canvasWidth,
                        y: node.rect.minY * canvasHeight,
                        width: node.rect.width * canvasWidth,
                        height: node.rect.height * canvasHeight
                    )

                    treemapBlock(node: node, rect: rect)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: GlassTheme.cardRadius, style: .continuous))
        .specularBorder(cornerRadius: GlassTheme.cardRadius)
    }

    private func treemapBlock(node: TreemapNode, rect: CGRect) -> some View {
        let isHovered = hoveredNodeID == node.id
        let isDir = node.categoryID == "directory"
        let isCategoryNode = node.categoryID != nil && node.categoryID != "directory" && node.categoryID != "file"

        let fillColor: Color = {
            if isCategoryNode {
                let category = coordinator.categories.first { $0.id == node.categoryID }
                return GlassTheme.color(for: category?.group ?? .developer)
            } else if isDir {
                return GlassTheme.atmosphericBlue
            } else {
                return GlassTheme.softLavender
            }
        }()

        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(fillColor.opacity(isHovered ? 0.95 : 0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isHovered ? GlassTheme.specularHighlightColor : Color.white.opacity(0.18),
                            lineWidth: isHovered ? 1.5 : 0.5
                        )
                )

            if rect.width > 60 && rect.height > 35 {
                VStack(spacing: 2) {
                    HStack(spacing: 3) {
                        if isDir {
                            Image(systemName: "folder")
                                .font(.system(size: 10))
                        }
                        Text(node.name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)

                    Text(DiskSpaceInfo.format(bytes: node.size))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                }
                .padding(4)
            }
        }
        .frame(width: max(0, rect.width - 2), height: max(0, rect.height - 2))
        .position(x: rect.midX, y: rect.midY)
        .onHover { hovering in
            hoveredNodeID = hovering ? node.id : nil
        }
        .onTapGesture {
            if isDir {
                Task {
                    try? await coordinator.analyzeDiskUsage(path: node.id)
                }
            } else if let catID = node.categoryID, isCategoryNode {
                coordinator.toggleCategorySelection(id: catID)
            }
        }
        .help("\(node.name): \(DiskSpaceInfo.format(bytes: node.size))\(isDir ? " (Click to open folder)" : "")")
    }

    private var emptyStateView: some View {
        AdaptiveGlassContainer {
            VStack(spacing: 16) {
                Image(systemName: "chart.pie")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Disk Analysis Data")
                    .font(.headline)
                Text("Analyze storage usage to generate a proportional visual treemap.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Analyze Current Directory") {
                    Task {
                        try? await coordinator.analyzeDiskUsage(path: coordinator.analyzedPath)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        }
    }
}
