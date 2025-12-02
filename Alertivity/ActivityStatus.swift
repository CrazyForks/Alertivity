import SwiftUI
import Foundation

struct StatusColorPalette {
    static let normal = Color.primary
    static let elevated = Color.yellow
    static let critical = Color.red

    static func color(for level: ActivityStatus.Level) -> Color {
        switch level {
        case .normal:
            return normal
        case .elevated:
            return elevated
        case .critical:
            return critical
        }
    }

    static func color(for severity: ActivityMetrics.MetricSeverity) -> Color? {
        switch severity {
        case .normal:
            return nil
        case .elevated:
            return elevated
        case .critical:
            return critical
        }
    }
}

struct ActivityStatus: Sendable, Equatable {
    enum Level: String, Sendable {
        case normal
        case elevated
        case critical
    }

    enum TriggerMetric: String, Sendable {
        case cpu
        case memory
        case disk
        case network
    }

    let level: Level
    let trigger: TriggerMetric?

    init(level: Level, trigger: TriggerMetric?) {
        self.level = level
        self.trigger = trigger
    }

    init(metrics: ActivityMetrics) {
        let cpuSeverity = metrics.cpuSeverity
        let memorySeverity = metrics.memorySeverity
        let diskSeverity = metrics.diskSeverity
        let networkSeverity = metrics.networkSeverity

        let ranked: [(TriggerMetric, ActivityMetrics.MetricSeverity, Double)] = [
            (.cpu, cpuSeverity, metrics.cpuUsagePercentage),
            (.memory, memorySeverity, metrics.memoryUsage),
            (.disk, diskSeverity, metrics.disk.totalBytesPerSecond),
            (.network, networkSeverity, metrics.network.totalBytesPerSecond)
        ]

        let highest = ranked.max { lhs, rhs in
            if lhs.1 == rhs.1 {
                return ActivityStatus.priority(for: lhs.0) < ActivityStatus.priority(for: rhs.0)
            }
            return lhs.1.rawValue < rhs.1.rawValue
        }

        if let highest, highest.1 != .normal {
            level = ActivityStatus.level(for: highest.1)
            trigger = highest.0
        } else {
            level = .normal
            trigger = nil
        }
    }

    private static func level(for severity: ActivityMetrics.MetricSeverity) -> Level {
        switch severity {
        case .critical:
            return .critical
        case .elevated:
            return .elevated
        case .normal:
            return .normal
        }
    }

    var accentColor: Color {
        StatusColorPalette.color(for: level)
    }

    var iconTint: Color? {
        switch level {
        case .normal:
            return nil
            
        case .elevated, .critical:
            return accentColor
        }
    }

    var symbolName: String {
        switch level {
        case .normal:
            return "waveform.path.ecg"
        case .elevated:
            return "waveform.path.ecg"
        case .critical:
            return "waveform.path"
        }
    }

    func title(for metrics: ActivityMetrics) -> String {
        let alignedStatus = statusAligned(to: metrics)
        let criticalMetrics = metricsBySeverity(metrics, target: .critical)
        let elevatedMetrics = metricsBySeverity(metrics, target: .elevated)

        switch alignedStatus.level {
        case .normal:
            return "System is stable"
        case .elevated:
            if elevatedMetrics.count > 1 {
                return "Multiple metrics elevated"
            }
            if let elevated = elevatedMetrics.first {
                return "Elevated \(metricDisplayName(elevated))"
            }
            return "Elevated \(alignedStatus.triggerLabel)"
        case .critical:
            if !criticalMetrics.isEmpty, !elevatedMetrics.isEmpty {
                let criticalText: String
                if criticalMetrics.count == 1, let onlyCritical = criticalMetrics.first {
                    criticalText = "Critical \(metricDisplayName(onlyCritical))"
                } else {
                    criticalText = "Critical \(listMetrics(criticalMetrics))"
                }

                let elevatedText: String
                if elevatedMetrics.count == 1, let onlyElevated = elevatedMetrics.first {
                    elevatedText = "\(metricDisplayName(onlyElevated)) elevated"
                } else {
                    elevatedText = "\(listMetrics(elevatedMetrics)) elevated"
                }

                return "\(criticalText); \(elevatedText)"
            }

            if criticalMetrics.count > 1 {
                return "Multiple metrics critical"
            }

            if let onlyCritical = criticalMetrics.first {
                return "Critical \(metricDisplayName(onlyCritical))"
            }

            return "Critical \(alignedStatus.triggerLabel)"
        }
    }

    func message(for metrics: ActivityMetrics) -> String {
        guard metrics.hasLiveData else {
            return "Collecting live metrics…"
        }

        let metricSummaries = notificationDescriptions(for: metrics)
        if metricSummaries.isEmpty {
            return "Everything looks healthy."
        }

        return metricSummaries.joined(separator: ", ")
    }

    func notificationTitle(for metrics: ActivityMetrics) -> String {
        title(for: metrics)
    }

    func menuSummary(for metrics: ActivityMetrics) -> String {
        guard metrics.hasLiveData else {
            return "Collecting live metrics…"
        }

        let criticalMetrics = metricsBySeverity(metrics, target: .critical)
        let elevatedMetrics = metricsBySeverity(metrics, target: .elevated)
        var metricSummaries: [String] = []

        if !criticalMetrics.isEmpty {
            metricSummaries.append(menuRationale(for: criticalMetrics, severity: .critical))
        }

        if !elevatedMetrics.isEmpty {
            metricSummaries.append(menuRationale(for: elevatedMetrics, severity: .elevated))
        }

        if metricSummaries.isEmpty {
            return "Everything looks healthy."
        }

        return metricSummaries.joined(separator: "; ")
    }

    func triggerValue(for metrics: ActivityMetrics) -> Double? {
        guard let trigger else { return nil }
        switch trigger {
        case .cpu:
            return metrics.cpuUsagePercentage
        case .memory:
            return metrics.memoryUsage
        case .disk:
            return metrics.disk.totalBytesPerSecond
        case .network:
            return metrics.network.totalBytesPerSecond
        }
    }

    private var triggerLabel: String {
        guard let trigger else { return "activity" }
        return triggerDisplayName(trigger)
    }

    private func triggerDisplayName(_ trigger: TriggerMetric) -> String {
        switch trigger {
        case .cpu:
            return "CPU"
        case .memory:
            return "Memory"
        case .disk:
            return "Disk"
        case .network:
            return "Network"
        }
    }

    private func metricDisplayName(_ metric: TriggerMetric) -> String {
        triggerDisplayName(metric)
    }

    private func formattedTriggerValue(for trigger: TriggerMetric, metrics: ActivityMetrics) -> String {
        switch trigger {
        case .cpu:
            return metrics.cpuUsagePercentage.formatted(.percent.precision(.fractionLength(0)))
        case .memory:
            return metrics.memoryUsage.formatted(.percent.precision(.fractionLength(0)))
        case .disk:
            return metrics.disk.formattedTotalPerSecond + "/s"
        case .network:
            return metrics.network.formattedBytesPerSecond(metrics.network.totalBytesPerSecond) + "/s"
        }
    }

    static let normal = ActivityStatus(level: .normal, trigger: nil)
    static let elevated = ActivityStatus(level: .elevated, trigger: .cpu)
    static let critical = ActivityStatus(level: .critical, trigger: .cpu)

    /// Keeps user-facing copy in sync with the latest metrics even if the stored status lags or differs.
    private func statusAligned(to metrics: ActivityMetrics) -> ActivityStatus {
        let metricsStatus = ActivityStatus(metrics: metrics)
        return metricsStatus
    }

    private func listMetrics(_ metrics: [TriggerMetric]) -> String {
        metrics.map { metricDisplayName($0) }.joined(separator: ", ")
    }

    private func naturalMetricList(_ metrics: [TriggerMetric]) -> String {
        let names = metrics.map { metricDisplayName($0) }
        switch names.count {
        case 0:
            return ""
        case 1:
            return names[0]
        case 2:
            return names.joined(separator: " and ")
        default:
            return names.joined(separator: ", ")
        }
    }

    private func metricsBySeverity(_ metrics: ActivityMetrics, target: ActivityMetrics.MetricSeverity) -> [TriggerMetric] {
        let pairs: [(TriggerMetric, ActivityMetrics.MetricSeverity)] = [
            (.cpu, metrics.cpuSeverity),
            (.memory, metrics.memorySeverity),
            (.disk, metrics.diskSeverity),
            (.network, metrics.networkSeverity)
        ]
        return pairs.filter { $0.1 == target }.map { $0.0 }
    }

    private func nonNormalMetrics(_ metrics: ActivityMetrics) -> [(TriggerMetric, ActivityMetrics.MetricSeverity)] {
        let pairs: [(TriggerMetric, ActivityMetrics.MetricSeverity)] = [
            (.cpu, metrics.cpuSeverity),
            (.memory, metrics.memorySeverity),
            (.disk, metrics.diskSeverity),
            (.network, metrics.networkSeverity)
        ]

        return pairs
            .filter { $0.1 != .normal }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return ActivityStatus.priority(for: lhs.0) > ActivityStatus.priority(for: rhs.0)
                }
                return lhs.1.rawValue > rhs.1.rawValue
            }
    }

    private static func priority(for trigger: TriggerMetric) -> Int {
        switch trigger {
        case .cpu:
            return 4
        case .memory:
            return 3
        case .disk:
            return 2
        case .network:
            return 1
        }
    }

    private func notificationDescriptions(for metrics: ActivityMetrics) -> [String] {
        nonNormalMetrics(metrics).map { metric, severity in
            let valueText = formattedValue(for: metric, metrics: metrics)
            let severityText = severityTag(for: severity)
            return "\(metricDisplayName(metric)) \(valueText) (\(severityText))"
        }
    }

    private func menuRationale(for metrics: [TriggerMetric], severity: ActivityMetrics.MetricSeverity) -> String {
        let list = naturalMetricList(metrics)
        let thresholds = metrics.count > 1 ? "thresholds" : "threshold"
        switch severity {
        case .critical:
            return "\(list) exceeded critical \(thresholds)"
        case .elevated:
            return "\(list) above elevated \(thresholds)"
        case .normal:
            return ""
        }
    }

    private func formattedValue(for metric: TriggerMetric, metrics: ActivityMetrics) -> String {
        switch metric {
        case .cpu:
            return metrics.cpuUsagePercentage.formatted(.percent.precision(.fractionLength(0)))
        case .memory:
            return metrics.memoryUsage.formatted(.percent.precision(.fractionLength(0)))
        case .disk:
            return metrics.disk.formattedTotalPerSecond + "/s"
        case .network:
            return metrics.network.formattedBytesPerSecond(metrics.network.totalBytesPerSecond) + "/s"
        }
    }

    private func severityTag(for severity: ActivityMetrics.MetricSeverity) -> String {
        switch severity {
        case .normal:
            return "normal"
        case .elevated:
            return "elev"
        case .critical:
            return "crit"
        }
    }
}
