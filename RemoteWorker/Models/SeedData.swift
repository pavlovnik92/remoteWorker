import Foundation
import SwiftData

/// Дефолтный набор «из коробки»: активности и библиотека разминок.
enum SeedData {
    static func seedIfNeeded(context: ModelContext) {
        seedActivitiesIfNeeded(context: context)
        seedExercisesIfNeeded(context: context)
        try? context.save()
    }

    static func makeDefaultTemplates() -> [ActivityTemplate] {
        [
            ActivityTemplate(name: "Фокус", iconName: "target", category: .work, sortOrder: 0, isBuiltIn: true, builtinKind: "focus"),
            ActivityTemplate(name: "Созвон", iconName: "video", category: .work, sortOrder: 1, isBuiltIn: true),
            ActivityTemplate(name: "Кофе", iconName: "cup.and.saucer.fill", category: .rest, sortOrder: 2, isBuiltIn: true),
            ActivityTemplate(name: "Обед", iconName: "fork.knife", category: .rest, sortOrder: 3, isBuiltIn: true),
            ActivityTemplate(name: "Прогулка", iconName: "figure.walk", category: .rest, sortOrder: 4, isBuiltIn: true),
            ActivityTemplate(name: "Разминка", iconName: "figure.cooldown", category: .health, sortOrder: 5, isBuiltIn: true, builtinKind: "warmup"),
            ActivityTemplate(name: "Соцсети", iconName: "iphone", category: .distraction, sortOrder: 6, isBuiltIn: true),
        ]
    }

    private static func seedActivitiesIfNeeded(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<ActivityTemplate>())) ?? 0
        guard count == 0 else { return }
        makeDefaultTemplates().forEach { context.insert($0) }
    }

    /// Возвращает удалённые стандартные активности (по имени), не трогая существующие.
    static func restoreDefaultTemplates(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<ActivityTemplate>())) ?? []
        let existingNames = Set(existing.map(\.name))
        for template in makeDefaultTemplates() where !existingNames.contains(template.name) {
            context.insert(template)
        }
        try? context.save()
    }

    /// Досев по имени: новые упражнения библиотеки появляются и на существующих установках.
    private static func seedExercisesIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let existingNames = Set(existing.map(\.name))
        for exercise in makeLibraryExercises() where !existingNames.contains(exercise.name) {
            context.insert(exercise)
        }
    }

    static func makeLibraryExercises() -> [Exercise] {
        [
            // MARK: Шея и плечи
            Exercise(
                name: "Наклоны шеи",
                zone: .neck,
                durationSeconds: 120,
                iconName: "figure.cooldown",
                details: "Медленно наклоняйте голову к каждому плечу, задерживаясь на вдохе. Тянет боковую поверхность шеи после долгой работы за столом.",
                steps: [
                    "Сядьте прямо, расслабьте плечи",
                    "Наклон вправо, держите 15 сек",
                    "Повторите влево, 4 круга",
                ]
            ),
            Exercise(
                name: "Круги плечами",
                zone: .neck,
                reps: 20,
                iconName: "arrow.trianglehead.2.clockwise.rotate.90",
                details: "Вперёд и назад по 10 кругов. Разгружает верх спины после сгорбленного сидения."
            ),
            Exercise(
                name: "Сведение лопаток",
                zone: .neck,
                reps: 15,
                iconName: "figure.arms.open",
                details: "Свести лопатки, задержать на 2 секунды и отпустить. Работает против сутулости."
            ),

            // MARK: Грудь и руки
            Exercise(
                name: "Раскрытие груди в проёме",
                zone: .chest,
                durationSeconds: 30,
                iconName: "door.left.hand.open",
                details: "Руки на дверной косяк, корпус подать вперёд. Компенсирует закрытую грудную клетку от работы за клавиатурой.",
                steps: [
                    "Ладони на косяк на уровне плеч",
                    "Корпус подать вперёд",
                    "Держите 20–30 секунд",
                ]
            ),
            Exercise(
                name: "Отжимания от стола",
                zone: .chest,
                reps: 12,
                iconName: "figure.strengthtraining.traditional",
                details: "От стола или стены, 10–15 раз. Спина прямая, локти вдоль корпуса."
            ),
            Exercise(
                name: "Обратные отжимания от стула",
                zone: .chest,
                reps: 10,
                iconName: "chair",
                details: "Руки на край устойчивого стула, опускайте таз вниз и выжимайте себя обратно. Нагружает трицепс."
            ),
            Exercise(
                name: "Кисти и запястья",
                zone: .wrists,
                durationSeconds: 60,
                iconName: "hand.raised.fill",
                details: "Потянуть ладонь на себя и от себя, по 15 секунд. Актуально при наборе текста весь день — профилактика туннельного синдрома.",
                steps: [
                    "Сожмите кулаки, 10 вращений",
                    "Вытяните руку, потяните ладонь на себя и от себя",
                    "Встряхните кисти",
                ]
            ),

            // MARK: Спина и корпус
            Exercise(
                name: "Прогиб спины",
                zone: .back,
                durationSeconds: 180,
                iconName: "figure.yoga",
                details: "Мягкий прогиб стоя раскрывает грудной отдел и компенсирует сидячую позу.",
                steps: [
                    "Встаньте, руки на поясницу",
                    "Плавный прогиб назад, 10 сек",
                    "Вернитесь, повторите 6 раз",
                ]
            ),
            Exercise(
                name: "Кошка-корова стоя",
                zone: .back,
                reps: 10,
                iconName: "figure.core.training",
                details: "Руки на бёдра: прогиб и округление спины по очереди. Мобилизует позвоночник."
            ),
            Exercise(
                name: "Наклоны корпуса в стороны",
                zone: .back,
                reps: 10,
                iconName: "figure.cooldown",
                details: "Рука над головой, наклон в сторону — по 5 в каждую. Тянет боковой пресс и поясницу."
            ),
            Exercise(
                name: "Повороты корпуса",
                zone: .back,
                reps: 16,
                iconName: "arrow.2.squarepath",
                details: "Сидя или стоя, по 8 поворотов в каждую сторону. Разгружает грудной отдел."
            ),
            Exercise(
                name: "Скрутка сидя",
                zone: .back,
                durationSeconds: 120,
                iconName: "arrow.2.squarepath",
                details: "Скрутка позвоночника сидя на стуле — доступно прямо на рабочем месте.",
                steps: [
                    "Сядьте боком к спинке стула",
                    "Скрутитесь к спинке, 20 сек",
                    "Повторите в другую сторону",
                ]
            ),
            Exercise(
                name: "«Супермен» на полу",
                zone: .back,
                reps: 10,
                iconName: "figure.core.training",
                details: "Лёжа на животе поднимайте руки и ноги одновременно. Укрепляет разгибатели спины — нужно место, чтобы лечь."
            ),

            // MARK: Глаза
            Exercise(
                name: "Гимнастика глаз",
                zone: .eyes,
                durationSeconds: 120,
                iconName: "eye",
                details: "Правило 20-20-20 и движения глазами снимают усталость от экрана.",
                steps: [
                    "Посмотрите вдаль 20 секунд",
                    "8 движений по горизонтали и вертикали",
                    "Закройте глаза ладонями на 30 сек",
                ],
                accentHex: 0x5B5BD6
            ),

            // MARK: Ноги и ягодицы
            Exercise(
                name: "Приседания",
                zone: .legs,
                reps: 15,
                iconName: "figure.strengthtraining.functional",
                details: "С собственным весом, в спокойном темпе. Спина прямая, колени не выходят за носки."
            ),
            Exercise(
                name: "Выпады назад",
                zone: .legs,
                reps: 16,
                iconName: "figure.step.training",
                details: "По 8 на каждую ногу. Шаг назад, колено передней ноги не выходит за носок."
            ),
            Exercise(
                name: "Выпад с опусканием таза",
                zone: .legs,
                durationSeconds: 60,
                iconName: "figure.strengthtraining.functional",
                details: "Растяжка сгибателей бедра — по 20–30 секунд на ногу. Ключевое упражнение против последствий сидения.",
                steps: [
                    "Выпад, заднее колено на пол",
                    "Таз подать вперёд и вниз",
                    "20–30 сек, поменяйте ногу",
                ]
            ),
            Exercise(
                name: "Подъёмы на носки",
                zone: .legs,
                reps: 20,
                iconName: "shoeprints.fill",
                details: "Гоняет кровь из ног — полезно против отёков при долгом сидении."
            ),
            Exercise(
                name: "Прогулка по дому",
                zone: .legs,
                durationSeconds: 300,
                iconName: "figure.walk",
                details: "Пять минут ходьбы — минимальная перезагрузка для ног и головы.",
                steps: [
                    "Встаньте из-за стола",
                    "Пройдитесь, посмотрите в окно",
                ],
                accentHex: 0x2BB3C0
            ),
        ]
    }
}
