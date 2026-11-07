// Proposito: Exibir o mes e selecionar um dia com compromissos da loja atual.
// Created by Jonathas Motta (@jonathaxs) on 2026-09-05.

import SwiftUI
import TinyStockCore

struct SalesOrderCalendarView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @AppStorage(AppAccentColor.storageKey) private var accentColorRaw = AppAccentColor.defaultColor.rawValue
    @Binding var selectedDate: Date
    let countsByDay: [Date: Int]

    private var accentColor: Color {
        (AppAccentColor(rawValue: accentColorRaw) ?? .defaultColor).color
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private var days: [Date] { SalesOrderSchedule.monthDays(containing: selectedDate, calendar: calendar) }
    private var weekdaySymbols: [String] {
        var localizedCalendar = calendar
        localizedCalendar.locale = locale
        let symbols = localizedCalendar.veryShortStandaloneWeekdaySymbols
        let offset = (calendar.firstWeekday - 1) % symbols.count
        return Array(symbols[offset...] + symbols[..<offset])
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                monthButton(offset: -1)
                Text(selectedDate, format: .dateTime.month(.wide).year())
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                monthButton(offset: 1)
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .accessibilityHidden(true)
                }
                ForEach(days, id: \.self) { day in dayButton(day) }
            }

            Button(String(localized: "order.calendar.today", bundle: .tinyStockCore)) {
                selectedDate = Date()
            }
            .frame(minHeight: 44)
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
    }

    private func monthButton(offset: Int) -> some View {
        let title = offset < 0
            ? String(localized: "order.calendar.previousMonth", bundle: .tinyStockCore)
            : String(localized: "order.calendar.nextMonth", bundle: .tinyStockCore)
        return Button {
            // Mover o mes tambem seleciona seu primeiro dia, evitando lista de outro mes.
            guard let start = calendar.dateInterval(of: .month, for: selectedDate)?.start,
                  let next = calendar.date(byAdding: .month, value: offset, to: start) else { return }
            selectedDate = next
        } label: {
            Image(systemName: offset < 0 ? "chevron.left" : "chevron.right")
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(title)
        .buttonStyle(.borderless)
        .help(title)
    }

    private func dayButton(_ day: Date) -> some View {
        let selected = calendar.isDate(day, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(day)
        let inMonth = calendar.isDate(day, equalTo: selectedDate, toGranularity: .month)
        let count = countsByDay[calendar.startOfDay(for: day), default: 0]
        return Button { selectedDate = day } label: {
            VStack(spacing: 2) {
                Text(calendar.component(.day, from: day), format: .number)
                    .font(.callout.weight(today ? .bold : .regular))
                    .lineLimit(1)
                Text(count == 0 ? " " : (count > 99 ? "99+" : count.formatted()))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            // Limita apenas o texto da grade para preservar sete colunas legiveis.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(maxWidth: .infinity)
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 68 : 52)
            .foregroundStyle(selected ? Color.white : (inMonth ? Color.primary : Color.secondary))
            .background(selected ? accentColor : .clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                if today && !selected {
                    RoundedRectangle(cornerRadius: 8).strokeBorder(accentColor, lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(locale)))
        .accessibilityValue(String(
            format: String(localized: "order.calendar.dayCount", bundle: .tinyStockCore), count.formatted()
        ))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityHint(today ? String(localized: "order.calendar.today", bundle: .tinyStockCore) : "")
    }
}
