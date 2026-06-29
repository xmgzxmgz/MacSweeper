import Foundation

public enum ScanPreset: String, Sendable, CaseIterable {
    case light
    case standard
    case deep
}

public enum SortMode: String, Sendable, CaseIterable {
    case bySize
    case byLowRisk
    case byOldest
}

public enum DuplicateRetainPolicy: String, Sendable, CaseIterable {
    case keepNewest
    case keepOldest
    case keepShortestPath
}

public struct UserSettings: Sendable {
    public var largeThresholdBytes: Int64
    public var oldDays: Int
    public var includeDuplicates: Bool
    public var dryRun: Bool
    public var excludePaths: [String]
    public var excludeExtensions: [String]
    public var preset: ScanPreset
    public var sortMode: SortMode
    public var hashConcurrency: Int
    public var useFastHash: Bool
    public var enableLogging: Bool
    public var duplicateRetainPolicy: DuplicateRetainPolicy

    public init(
        largeThresholdBytes: Int64 = 1_000_000_000,
        oldDays: Int = 365,
        includeDuplicates: Bool = true,
        dryRun: Bool = false,
        excludePaths: [String] = [],
        excludeExtensions: [String] = [],
        preset: ScanPreset = .standard,
        sortMode: SortMode = .bySize,
        hashConcurrency: Int = 4,
        useFastHash: Bool = true,
        enableLogging: Bool = false,
        duplicateRetainPolicy: DuplicateRetainPolicy = .keepNewest
    ) {
        self.largeThresholdBytes = largeThresholdBytes
        self.oldDays = oldDays
        self.includeDuplicates = includeDuplicates
        self.dryRun = dryRun
        self.excludePaths = excludePaths
        self.excludeExtensions = excludeExtensions
        self.preset = preset
        self.sortMode = sortMode
        self.hashConcurrency = hashConcurrency
        self.useFastHash = useFastHash
        self.enableLogging = enableLogging
        self.duplicateRetainPolicy = duplicateRetainPolicy
    }
}

public struct FilterOptions: Sendable {
    public var kinds: Set<SuggestionKind>
    public var minSizeBytes: Int64?
    public var maxSizeBytes: Int64?
    public var searchText: String
    public var regexPattern: String?
    public var wildcardPattern: String?

    public init(kinds: Set<SuggestionKind> = Set(SuggestionKind.allCases), minSizeBytes: Int64? = nil, maxSizeBytes: Int64? = nil, searchText: String = "", regexPattern: String? = nil, wildcardPattern: String? = nil) {
        self.kinds = kinds
        self.minSizeBytes = minSizeBytes
        self.maxSizeBytes = maxSizeBytes
        self.searchText = searchText
        self.regexPattern = regexPattern
        self.wildcardPattern = wildcardPattern
    }
}

// SuggestionKind already conforms to CaseIterable in Models.swift