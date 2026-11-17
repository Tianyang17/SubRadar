import SubRadarCore
import SwiftUI

struct FlowFieldBadges: View {
    @Environment(\.radarPalette) private var palette
    let fields: [FieldSchema]
    var maxVisibleCount: Int = 4
    var onMoreTapped: (() -> Void)? = nil

    var body: some View {
        let visible = Array(fields.prefix(maxVisibleCount))
        let overflowCount = max(0, fields.count - maxVisibleCount)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(visible) { field in
                HStack(spacing: 4) {
                    if field.type == .secret {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(SubRadarTheme.amber)
                    }
                    Text(field.label)
                        .font(SubRadarTheme.font(size: 11, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.inputSurface, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            if overflowCount > 0 {
                Button {
                    onMoreTapped?()
                } label: {
                    Text("+\(overflowCount) 项更多字段")
                        .font(SubRadarTheme.font(size: 11, weight: .semibold))
                        .foregroundStyle(SubRadarTheme.radarAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            SubRadarTheme.radarAccent.opacity(0.09),
                            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
