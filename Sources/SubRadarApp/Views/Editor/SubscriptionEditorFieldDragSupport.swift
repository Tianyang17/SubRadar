import SubRadarCore
import SwiftUI

struct CustomFieldDragHandle: View {
    @Environment(\.radarPalette) private var palette
    @State private var isHovered = false
    let isDragging: Bool

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isDragging || isHovered ? SubRadarTheme.radarAccent : palette.textMuted)
            .frame(width: 22, height: 28)
            .contentShape(Rectangle())
            .background(
                (isDragging || isHovered ? SubRadarTheme.radarAccent.opacity(0.08) : Color.clear),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .onHover { isHovered = $0 }
            .help("按住上下拖拽调整字段顺序")
    }
}

struct CustomFieldReorderDropDelegate: DropDelegate {
    let targetFieldId: UUID
    @Binding var draggingFieldId: UUID?
    let onMove: (UUID, UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggingFieldId, draggedId != targetFieldId else { return }
        withAnimation(.snappy(duration: 0.18)) {
            onMove(draggedId, targetFieldId)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingFieldId = nil
        return true
    }

    func dropExited(info: DropInfo) {
        // 保持拖拽状态直到 drop 结束或取消，避免跨行抖动
    }
}
