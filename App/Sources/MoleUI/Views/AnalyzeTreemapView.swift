import SwiftUI
import MoleEngine

public struct AnalyzeTreemapView: View {
    @Bindable public var coordinator: MoleCoordinator
    @State private var hoveredNodeID: String? = nil

    public init(coordinator: MoleCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView

            if let root = coordinator.treemapRoot, !root.children.isEmpty {
                treemapCanvas(root: root)
            } else {
                emptyStateView
            }
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 450)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Disk Space Treemap")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Proportional visualization of reclaimable storage")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if coordinator.isScanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task {
                            try? await coordinator.scanReclaimableSpace()
                        }
                    } label: {
                        Label("Re-scan", systemImage: "arrow.clockwise")
                    }
                    .help("Re-scan system to refresh treemap")
                }
            }

            // Breadcrumbs Bar
            HStack(spacing: 6) {
                Image(systemName: "internaldrive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Macintosh HD")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text("~/Library/Caches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let hovered = hoveredNodeID, let node = coordinator.treemapRoot?.children.first(where: { $0.id == hovered }) {
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
        }
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
        let category = coordinator.categories.first { $0.id == node.categoryID }
        let group = category?.group ?? .developer
        let isSelected = category?.isSelected ?? true

        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(GlassTheme.gradient(for: group).opacity(isSelected ? (isHovered ? 1.0 : 0.85) : 0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isHovered ? GlassTheme.specularHighlightColor : Color.white.opacity(0.15),
                            lineWidth: isHovered ? 1.5 : 0.5
                        )
                )

            if rect.width > 60 && rect.height > 35 {
                VStack(spacing: 2) {
                    Text(node.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
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
            guard let catID = node.categoryID, !(category?.isProtectedByTCC ?? false) else { return }
            coordinator.toggleCategorySelection(id: catID)
        }
        .help("\(node.name): \(DiskSpaceInfo.format(bytes: node.size)) (Click to toggle)")
    }

    private var emptyStateView: some View {
        AdaptiveGlassContainer {
            VStack(spacing: 16) {
                Image(systemName: "chart.pie")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Scan Data Available")
                    .font(.headline)
                Text("Run a scan to generate a proportional visual treemap of cleanable junk.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Start Scan") {
                    Task {
                        try? await coordinator.scanReclaimableSpace()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        }
    }
}
