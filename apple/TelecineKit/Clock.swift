//  Clock.swift — small formatting helpers shared by the receiver and its widgets.

import Foundation

public enum Clock {
    /// mm:ss, or h:mm:ss once an hour has passed — the set's readout format.
    public static func readout(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        let mm = String(format: "%02d", m), ss = String(format: "%02d", sec)
        return h > 0 ? "\(h):\(mm):\(ss)" : "\(mm):\(ss)"
    }
    /// The guide's time column: local time, with the weekday when it is not today.
    public static func guideTime(_ date: Date, relativeTo now: Date = .now, calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return time }
        let day = date.formatted(.dateTime.weekday(.abbreviated))
        return "\(day) \(time)"
    }
}
