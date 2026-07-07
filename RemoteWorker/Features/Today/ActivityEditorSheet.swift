import SwiftData
import SwiftUI

/// S2a · Добавить/редактировать активность (bottom sheet).
struct ActivityEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let template: ActivityTemplate?

    @State private var name: String
    @State private var iconName: String
    @State private var colorHex: Int?
    @State private var category: ActivityCategory
    @State private var plannedMinutes: Int?

    init(template: ActivityTemplate?) {
        self.template = template
        _name = State(initialValue: template?.name ?? "")
        _iconName = State(initialValue: template?.iconName ?? "target")
        _colorHex = State(initialValue: template?.colorHex)
        _category = State(initialValue: template?.category ?? .work)
        _plannedMinutes = State(initialValue: template?.plannedMinutes)
    }

    private static let limitOptions = [10, 15, 20, 25, 30, 45, 60, 90]

    private static let icons: [String] = [
        "target", "laptopcomputer", "video", "phone.fill", "envelope.fill",
        "chevron.left.forwardslash.chevron.right", "book.fill", "music.note",
        "cup.and.saucer.fill", "fork.knife", "figure.walk", "figure.cooldown",
        "iphone", "gamecontroller.fill", "cart.fill", "graduationcap.fill",
        "paintbrush.pointed.fill", "calendar",
    ]

    private static let swatches: [Int] = [
        0x3B79D8, 0xE0913B, 0x1E8A5B, 0xD8634A, 0x7A5AF0, 0x2BB3C0,
    ]

    private var previewColor: Color {
        if let colorHex { return Color(hex: UInt32(colorHex)) }
        return category.color
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 18)
                .padding(.horizontal, 22)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    preview
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                    fieldSection("Название") {
                        TextField("Например, Дизайн-ревью", text: $name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.text)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .cardStyle(cornerRadius: 14)
                    }

                    fieldSection("Иконка") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 6), spacing: 9) {
                            ForEach(Self.icons, id: \.self) { icon in
                                iconCell(icon)
                            }
                        }
                    }

                    fieldSection("Цвет и категория") {
                        VStack(spacing: 14) {
                            HStack(spacing: 10) {
                                ForEach(Self.swatches, id: \.self) { hex in
                                    swatch(hex)
                                }
                                Spacer()
                            }
                            categoryPicker
                        }
                    }

                    fieldSection("Таймер") {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Пора заканчивать")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.text)
                                Text("напомним, когда активность затянулась")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.text3)
                            }
                            Spacer()
                            Picker("Лимит", selection: $plannedMinutes) {
                                Text("Выкл").tag(Int?.none)
                                ForEach(Self.limitOptions, id: \.self) { minutes in
                                    Text("\(minutes) мин").tag(Int?.some(minutes))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(plannedMinutes == nil ? Theme.text2 : Theme.accent)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .cardStyle(cornerRadius: 14)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }

            Button(action: save) {
                Text("Сохранить активность")
            }
            .buttonStyle(AccentButtonStyle(height: 54, cornerRadius: 16))
            .disabled(trimmedName.isEmpty)
            .opacity(trimmedName.isEmpty ? 0.5 : 1)
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
        }
        .background(Theme.bg)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var header: some View {
        ZStack {
            Text("Активность")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
            HStack {
                Button("Отмена") { dismiss() }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.text2)
                Spacer()
                Button("Готово") { save() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(trimmedName.isEmpty ? Theme.text3 : Theme.accent)
                    .disabled(trimmedName.isEmpty)
            }
        }
    }

    private var preview: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            previewColor.mix(with: Theme.card, by: 0.74),
                            previewColor.mix(with: Theme.card, by: 0.84),
                        ],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .overlay(Circle().strokeBorder(previewColor.opacity(0.3), lineWidth: 1))
            VStack(spacing: 5) {
                Image(systemName: iconName)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(previewColor)
                Text(trimmedName.isEmpty ? "Новая" : trimmedName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
            }
        }
        .frame(width: 96, height: 96)
        .shadow(color: previewColor.opacity(0.35), radius: 13, y: 8)
    }

    @ViewBuilder
    private func fieldSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(Theme.text2)
            content()
        }
    }

    private func iconCell(_ icon: String) -> some View {
        let selected = icon == iconName
        return Button {
            iconName = icon
        } label: {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(selected ? previewColor.opacity(0.16) : Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            selected ? previewColor : Theme.separator,
                            lineWidth: selected ? 2 : 1
                        )
                )
                .frame(height: 46)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 19))
                        .foregroundStyle(selected ? previewColor : Theme.text2)
                )
        }
        .buttonStyle(.plain)
    }

    private func swatch(_ hex: Int) -> some View {
        let color = Color(hex: UInt32(hex))
        let selected = colorHex == hex
        return Button {
            colorHex = hex
        } label: {
            Circle()
                .fill(color)
                .frame(width: 34, height: 34)
                .overlay {
                    if selected {
                        Circle()
                            .inset(by: -5)
                            .stroke(color, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var categoryPicker: some View {
        HStack(spacing: 6) {
            ForEach(ActivityCategory.allCases) { item in
                let selected = item == category
                Button {
                    category = item
                } label: {
                    Text(item.shortTitle)
                        .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Theme.text : Theme.text2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Theme.card)
                                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.card2)
        )
    }

    private func save() {
        let finalName = trimmedName
        guard !finalName.isEmpty else { return }

        if let template {
            template.name = finalName
            template.iconName = iconName
            template.colorHex = colorHex
            template.category = category
            template.plannedMinutes = plannedMinutes
        } else {
            let count = (try? context.fetchCount(FetchDescriptor<ActivityTemplate>())) ?? 0
            let newTemplate = ActivityTemplate(
                name: finalName,
                iconName: iconName,
                category: category,
                colorHex: colorHex,
                plannedMinutes: plannedMinutes,
                sortOrder: count
            )
            context.insert(newTemplate)
        }
        try? context.save()
        dismiss()
    }
}
