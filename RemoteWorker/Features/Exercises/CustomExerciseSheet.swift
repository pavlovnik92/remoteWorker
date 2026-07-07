import SwiftData
import SwiftUI

/// E4a · Создать своё упражнение (bottom sheet).
struct CustomExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private enum Dosage: String, CaseIterable, Identifiable {
        case time = "Время"
        case reps = "Повторы"
        var id: String { rawValue }
    }

    @State private var name = ""
    @State private var zone: BodyZone = .other
    @State private var dosage: Dosage = .reps
    @State private var minutes = 2
    @State private var reps = 15
    @State private var iconName = "figure.strengthtraining.functional"
    @State private var isExternal = false

    private static let icons: [String] = [
        "figure.strengthtraining.functional", "figure.walk", "figure.cooldown",
        "figure.yoga", "hand.raised.fill", "eye",
    ]

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Например, Отжимания", text: $name)
                }

                Section("Зона") {
                    Picker("Зона тела", selection: $zone) {
                        ForEach(BodyZone.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section("Нагрузка") {
                    Picker("Тип", selection: $dosage) {
                        ForEach(Dosage.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if dosage == .time {
                        Stepper("Длительность: \(minutes) мин", value: $minutes, in: 1...30)
                    } else {
                        Stepper("Повторы: \(reps)", value: $reps, in: 5...100, step: 5)
                    }
                }

                Section("Иконка") {
                    HStack(spacing: 10) {
                        ForEach(Self.icons, id: \.self) { icon in
                            let selected = icon == iconName
                            Button {
                                iconName = icon
                            } label: {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selected ? Theme.accent.opacity(0.16) : Theme.card2)
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(selected ? Theme.accent : .clear, lineWidth: 2)
                                    )
                                    .overlay(
                                        Image(systemName: icon)
                                            .font(.system(size: 18))
                                            .foregroundStyle(selected ? Theme.accent : Theme.text2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    Toggle("Выполняю вне приложения", isOn: $isExternal)
                } footer: {
                    Text("Без анимации и таймера — просто трекаем факт выполнения.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Своё упражнение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
        .tint(Theme.accent)
        .presentationDetents([.large])
    }

    private func save() {
        let exercise = Exercise(
            name: trimmedName,
            zone: zone,
            durationSeconds: dosage == .time ? minutes * 60 : 0,
            reps: dosage == .reps ? reps : 0,
            iconName: iconName,
            isExternal: isExternal,
            isCustom: true
        )
        context.insert(exercise)
        try? context.save()
        dismiss()
    }
}
