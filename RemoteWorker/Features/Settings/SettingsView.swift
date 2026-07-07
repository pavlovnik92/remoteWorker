import SwiftData
import SwiftUI

/// ST1 · Настройки: перерывы, вид, активности, интеграции (заглушки MVP).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettings.breakIntervalKey) private var breakInterval = 50
    @AppStorage(AppSettings.adaptiveBreaksKey) private var adaptiveBreaks = false
    @AppStorage(AppSettings.quietStartKey) private var quietStart = 22 * 60
    @AppStorage(AppSettings.quietEndKey) private var quietEnd = 8 * 60
    @AppStorage(AppSettings.notificationsEnabledKey) private var notificationsEnabled = true
    @AppStorage(AppSettings.themeKey) private var themeRaw = AppTheme.system.rawValue
    @AppStorage(AppSettings.userNameKey) private var userName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Перерывы") {
                    Picker("Интервал", selection: $breakInterval) {
                        ForEach([30, 40, 50, 60, 90], id: \.self) {
                            Text("\($0) мин").tag($0)
                        }
                    }
                    Toggle("Напоминания", isOn: $notificationsEnabled)
                    Toggle("Адаптивно по нагрузке", isOn: $adaptiveBreaks)
                    Picker("Тихие часы · с", selection: $quietStart) {
                        ForEach(hourOptions, id: \.self) {
                            Text(hourLabel($0)).tag($0)
                        }
                    }
                    Picker("Тихие часы · до", selection: $quietEnd) {
                        ForEach(hourOptions, id: \.self) {
                            Text(hourLabel($0)).tag($0)
                        }
                    }
                }

                Section("Вид") {
                    Picker("Тема", selection: $themeRaw) {
                        ForEach(AppTheme.allCases) {
                            Text($0.title).tag($0.rawValue)
                        }
                    }
                    TextField("Имя для приветствия", text: $userName)
                }

                Section("Активности") {
                    NavigationLink("Активности по умолчанию") {
                        ManageActivitiesView()
                    }
                }

                Section {
                    integrationRow("Apple Health", icon: "heart.fill", color: Color(hex: 0xFF5A5F))
                    integrationRow("Виджеты и Live Activity", icon: "square.grid.2x2.fill", color: ActivityCategory.health.color)
                    integrationRow("Apple Watch", icon: "applewatch", color: Theme.text)
                } header: {
                    Text("Интеграции")
                } footer: {
                    Text("Появятся в следующих версиях — архитектура уже готова к ним.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .tint(Theme.accent)
    }

    private var hourOptions: [Int] {
        (0..<24).map { $0 * 60 }
    }

    private func hourLabel(_ minutes: Int) -> String {
        String(format: "%02d:00", minutes / 60)
    }

    private func integrationRow(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                )
            Text(title)
                .foregroundStyle(Theme.text)
            Spacer()
            Text("скоро")
                .font(.system(size: 14))
                .foregroundStyle(Theme.text3)
        }
    }
}

/// Управление шаблонами активностей: удаление и восстановление стандартных.
struct ManageActivitiesView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [
        SortDescriptor(\ActivityTemplate.sortOrder),
        SortDescriptor(\ActivityTemplate.createdAt),
    ])
    private var templates: [ActivityTemplate]

    var body: some View {
        List {
            Section {
                ForEach(templates, id: \.persistentModelID) { template in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(template.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: template.iconName)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(template.name)
                                .foregroundStyle(Theme.text)
                            Text(template.category.title)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.text3)
                        }
                    }
                }
                .onDelete(perform: delete)
            } footer: {
                Text("Смахни строку влево, чтобы удалить. История дней сохранится.")
            }

            Section {
                Button("Восстановить стандартные") {
                    SeedData.restoreDefaultTemplates(context: context)
                }
                .foregroundStyle(Theme.accent)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle("Активности")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(templates[index])
        }
        try? context.save()
    }
}
