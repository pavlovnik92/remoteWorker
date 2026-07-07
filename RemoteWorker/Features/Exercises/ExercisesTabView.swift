import SwiftData
import SwiftUI

/// E1 · Библиотека + E4 · Мой набор (сегменты одной вкладки).
struct ExercisesTabView: View {
    private enum Segment: String, CaseIterable, Identifiable {
        case library = "Библиотека"
        case mySet = "Мой набор"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .library
    @State private var searchText = ""
    @State private var zoneFilter: BodyZone?
    @State private var showCustomSheet = false

    @Query(sort: [SortDescriptor(\Exercise.createdAt)])
    private var exercises: [Exercise]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("Раздел", selection: $segment) {
                        ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch segment {
                    case .library: libraryContent
                    case .mySet: mySetContent
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
            .background(Theme.bg)
            .navigationTitle("Разминки")
            .toolbar {
                if segment == .mySet {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showCustomSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
            .sheet(isPresented: $showCustomSheet) {
                CustomExerciseSheet()
            }
        }
        .tint(Theme.accent)
    }

    // MARK: - Библиотека

    private var libraryFiltered: [Exercise] {
        exercises.filter { exercise in
            guard !exercise.isCustom else { return false }
            if let zoneFilter, exercise.zone != zoneFilter { return false }
            if !searchText.isEmpty,
               !exercise.name.localizedCaseInsensitiveContains(searchText) {
                return false
            }
            return true
        }
    }

    private var libraryContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.text3)
                TextField("Поиск упражнения", text: $searchText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .cardStyle(cornerRadius: 13)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    zoneChip(nil, title: "Все")
                    ForEach([BodyZone.neck, .back, .chest, .wrists, .eyes, .legs]) { zone in
                        zoneChip(zone, title: zone.chipTitle)
                    }
                }
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(libraryFiltered, id: \.persistentModelID) { exercise in
                    NavigationLink(value: exercise) {
                        exerciseGridCard(exercise)
                    }
                    .buttonStyle(.plain)
                }
            }

            if libraryFiltered.isEmpty {
                Text("Ничего не нашлось")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text3)
                    .padding(.top, 30)
            }
        }
    }

    private func zoneChip(_ zone: BodyZone?, title: String) -> some View {
        let selected = zone == zoneFilter
        return Button {
            zoneFilter = zone
        } label: {
            Text(title)
                .font(.system(size: 13, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? .white : Theme.text2)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    Capsule().fill(selected ? Theme.accent : Theme.card)
                )
                .overlay {
                    if !selected {
                        Capsule().strokeBorder(Theme.separator, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func exerciseGridCard(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(exercise.accentColor.mix(with: Theme.card2, by: 0.86))
                .frame(height: 78)
                .overlay(
                    Image(systemName: exercise.iconName)
                        .font(.system(size: 30))
                        .foregroundStyle(exercise.accentColor)
                )
                .padding(.bottom, 10)
            Text(exercise.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Text("\(exercise.dosageText) · \(exercise.zone.title)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text2)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 20)
    }

    // MARK: - Мой набор

    private var favorites: [Exercise] { exercises.filter { $0.isFavorite && !$0.isCustom } }
    private var custom: [Exercise] { exercises.filter { $0.isCustom } }

    private var mySetContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            setSection("Избранное", items: favorites, emptyText: "Отмечай сердечком упражнения из библиотеки")
            setSection("Свои упражнения", items: custom, emptyText: "Добавь своё — например, отжимания между созвонами")
        }
    }

    @ViewBuilder
    private func setSection(_ title: String, items: [Exercise], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(Theme.text2)
                .padding(.horizontal, 4)

            if items.isEmpty {
                Text(emptyText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .cardStyle(cornerRadius: 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.persistentModelID) { index, exercise in
                        NavigationLink(value: exercise) {
                            setRow(exercise)
                        }
                        .buttonStyle(.plain)
                        if index < items.count - 1 {
                            Divider().overlay(Theme.separator).padding(.leading, 70)
                        }
                    }
                }
                .cardStyle(cornerRadius: 18)
            }
        }
    }

    private func setRow(_ exercise: Exercise) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(exercise.accentColor.mix(with: Theme.card2, by: 0.86))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: exercise.iconName)
                        .font(.system(size: 20))
                        .foregroundStyle(exercise.accentColor)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                HStack(spacing: 6) {
                    Text("\(exercise.dosageText) · \(exercise.zone.title)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.text2)
                    if exercise.isExternal {
                        Text("вне приложения")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.violet)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .background(Capsule().fill(Theme.violet.opacity(0.16)))
                    }
                }
            }

            Spacer()

            if exercise.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(ActivityCategory.distraction.color)
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }
}
