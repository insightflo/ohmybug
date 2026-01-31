@testable import OhMyBugCore
import Foundation
import Testing

@Test func severityOrdering() {
    #expect(Severity.low < Severity.medium)
    #expect(Severity.medium < Severity.high)
    #expect(Severity.high < Severity.critical)
}

@Test func issueSummaryFromIssues() {
    let issues = [
        Issue(rule: "r1", message: "m1", severity: .critical, filePath: "f.swift", scanner: "test"),
        Issue(rule: "r2", message: "m2", severity: .high, filePath: "f.swift", scanner: "test"),
        Issue(rule: "r3", message: "m3", severity: .medium, filePath: "f.swift", scanner: "test"),
        Issue(rule: "r4", message: "m4", severity: .medium, filePath: "f.swift", scanner: "test"),
        Issue(rule: "r5", message: "m5", severity: .low, filePath: "f.swift", scanner: "test"),
    ]

    let summary = IssueSummary.from(issues: issues)
    #expect(summary.total == 5)
    #expect(summary.critical == 1)
    #expect(summary.high == 1)
    #expect(summary.medium == 2)
    #expect(summary.low == 1)
}

@Test func projectDetectorReturnsAutoForEmptyDir() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let detected = ProjectDetector.detect(at: tempDir.path)
    #expect(detected == .auto)
}

@Test func scanPhaseActivePhases() {
    let active = ScanPhase.activePhases
    #expect(active.count == 5)
    #expect(active.contains(.build))
    #expect(active.contains(.scan))
    #expect(!active.contains(.idle))
    #expect(!active.contains(.complete))
}
