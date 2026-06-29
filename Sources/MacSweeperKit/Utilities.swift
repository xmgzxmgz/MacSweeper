import Foundation

// MARK: - Byte Formatting

/// 将字节数格式化为人类可读的字符串（如 1.50 GB）
public func formatBytes(_ bytes: Int64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = Double(bytes)
    var idx = 0
    while value >= 1024 && idx < units.count - 1 {
        value /= 1024
        idx += 1
    }
    return String(format: "%.2f %@", value, units[idx])
}

/// 将字节数格式化为简洁的输入友好格式（如 1GB, 500MB）
public func formatBytesInput(_ bytes: Int64) -> String {
    if bytes % (1024 * 1024 * 1024) == 0 { return "\(bytes / (1024 * 1024 * 1024))GB" }
    if bytes % (1024 * 1024) == 0 { return "\(bytes / (1024 * 1024))MB" }
    if bytes % 1024 == 0 { return "\(bytes / 1024)KB" }
    return "\(bytes)"
}

// MARK: - Byte Parsing

/// 解析人类可读的大小字符串为字节数（支持 KB/MB/GB 后缀）
public func parseSizeToBytes(_ s: String) -> Int64? {
    let lower = s.lowercased().trimmingCharacters(in: .whitespaces)
    if lower.hasSuffix("kb"), let num = Double(lower.dropLast(2)) { return Int64(num * 1024) }
    if lower.hasSuffix("mb"), let num = Double(lower.dropLast(2)) { return Int64(num * 1024 * 1024) }
    if lower.hasSuffix("gb"), let num = Double(lower.dropLast(2)) { return Int64(num * 1024 * 1024 * 1024) }
    if lower.hasSuffix("tb"), let num = Double(lower.dropLast(2)) { return Int64(num * 1024 * 1024 * 1024 * 1024) }
    return Int64(lower)
}

// MARK: - Relative Time

/// 计算相对于当前时间的描述
public func relativeTime(_ date: Date?) -> String {
    guard let date else { return "无访问记录" }
    let diff = Int(Date().timeIntervalSince(date))
    if diff < 0 { return "刚刚" }
    let days = diff / (24 * 3600)
    if days >= 365 { return "访问于 \(days / 365) 年前" }
    if days >= 30 { return "访问于 \(days / 30) 个月前" }
    if days >= 1 { return "访问于 \(days) 天前" }
    let hours = (diff % (24 * 3600)) / 3600
    if hours >= 1 { return "访问于 \(hours) 小时前" }
    let minutes = (diff % 3600) / 60
    return "访问于 \(minutes) 分钟前"
}
