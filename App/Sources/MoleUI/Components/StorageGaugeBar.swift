import SwiftUI
import MoleEngine

public struct StorageProportions: Sendable, Equatable {
    public var usedRatio: Double
    public var reclaimableRatio: Double
    public var freeRatio: Double

    public init(usedRatio: Double, reclaimableRatio: Double, freeRatio: Double) {
        self.usedRatio = usedRatio
        self.reclaimableRatio = reclaimableRatio
        self.freeRatio = freeRatio
    }
}

public struct StorageGaugeBar: View {
    public var diskSpace: DiskSpaceInfo
    public var height: CGFloat

    public init(diskSpace: DiskSpaceInfo, height: CGFloat = 14.0) {
        self.diskSpace = diskSpace
        self.height = height
    }

    public static func calculateProportions(diskSpace: DiskSpaceInfo) -> StorageProportions {
        guard diskSpace.totalBytes > 0 else {
            return StorageProportions(usedRatio: 0.0, reclaimableRatio: 0.0, freeRatio: 0.0)
        }

        let total = Double(diskSpace.totalBytes)
        let free = Double(min(diskSpace.totalBytes, max(0, diskSpace.freeBytes)))
        let used = max(0, total - free)
        let reclaimable = min(Double(max(0, diskSpace.reclaimableBytes)), used)
        let usedNonReclaimable = max(0, used - reclaimable)

        return StorageProportions(
            usedRatio: usedNonReclaimable / total,
            reclaimableRatio: reclaimable / total,
            freeRatio: free / total
        )
    }

    public var body: some View {
        let proportions = Self.calculateProportions(diskSpace: diskSpace)
        let effectiveReclaimable = min(diskSpace.reclaimableBytes, diskSpace.usedBytes)
        let nonReclaimableUsed = max(0, diskSpace.usedBytes - effectiveReclaimable)

        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let activeSegments = (proportions.usedRatio > 0 ? 1 : 0) +
                                     (proportions.reclaimableRatio > 0 ? 1 : 0) +
                                     (proportions.freeRatio > 0 ? 1 : 0)
                let totalSpacing = CGFloat(max(0, activeSegments - 1)) * 2.0
                let availableWidth = max(0, totalWidth - totalSpacing)
                let usedWidth = availableWidth * proportions.usedRatio
                let reclaimableWidth = availableWidth * proportions.reclaimableRatio
                let freeWidth = max(0, availableWidth - usedWidth - reclaimableWidth)

                HStack(spacing: 2) {
                    // 1. Used Space (Non-reclaimable)
                    if usedWidth > 0 {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: usedWidth)
                            .help("Used: \(DiskSpaceInfo.format(bytes: nonReclaimableUsed))")
                    }

                    // 2. Reclaimable Space (Mole Targets)
                    if reclaimableWidth > 0 {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.orange.opacity(0.85), Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: reclaimableWidth)
                            .help("Reclaimable: \(DiskSpaceInfo.format(bytes: effectiveReclaimable))")
                    }

                    // 3. Free Space
                    if freeWidth > 0 {
                        Rectangle()
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: freeWidth)
                            .help("Free: \(DiskSpaceInfo.format(bytes: diskSpace.freeBytes))")
                    }
                }
                .clipShape(Capsule())
                .specularBorder(cornerRadius: height / 2, lineWidth: 0.5)
            }
            .frame(height: height)
            .animation(.easeInOut(duration: 0.35), value: diskSpace)

            // Legend
            HStack(spacing: 16) {
                legendItem(
                    title: "Used",
                    color: Color.blue,
                    bytes: nonReclaimableUsed
                )
                legendItem(
                    title: "Reclaimable",
                    color: Color.orange,
                    bytes: effectiveReclaimable
                )
                legendItem(
                    title: "Free",
                    color: Color.secondary.opacity(0.5),
                    bytes: diskSpace.freeBytes
                )
                Spacer()
                Text("Total: \(DiskSpaceInfo.format(bytes: diskSpace.totalBytes))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func legendItem(title: String, color: Color, bytes: Int64) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(DiskSpaceInfo.format(bytes: max(0, bytes)))
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}
