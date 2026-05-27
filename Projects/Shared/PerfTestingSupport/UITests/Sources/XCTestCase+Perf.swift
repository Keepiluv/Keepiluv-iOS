import XCTest

/// feature ready marker가 나타날 때까지 기다립니다.
/// Example host가 `perfReadyMarker(_:)`를 노출한 뒤 action을 시작하도록 맞추는 helper입니다.
///
/// ## 사용 예시
/// ```swift
/// waitForFeatureReady("home")
/// ```
public func waitForFeatureReady(
    _ slug: String,
    timeout: TimeInterval = 10,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let app = XCUIApplication()
    let ready = app.descendants(matching: .any)["feature.\(slug).ready"]
    XCTAssertTrue(
        ready.waitForExistence(timeout: timeout),
        "Timed out waiting for feature.\(slug).ready",
        file: file,
        line: line
    )
}

/// `perfStateMarker(slug:key:value:)`가 특정 값으로 나타날 때까지 기다립니다.
/// 값마다 accessibility identifier가 달라지므로 SwiftUI가 state mutation을
/// 반영했는지 확인할 수 있습니다.
///
/// ## 사용 예시
/// ```swift
/// awaitPerfMarker(slug: "home", key: "toast", value: "visible")
/// ```
public func awaitPerfMarker(
    slug: String,
    key: String,
    value: String,
    timeout: TimeInterval = 5,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let app = XCUIApplication()
    let identifier = "feature.\(slug).marker.\(key).\(value)"
    let marker = app.descendants(matching: .any)[identifier]
    XCTAssertTrue(
        marker.waitForExistence(timeout: timeout),
        "Timed out waiting for marker \(identifier)",
        file: file,
        line: line
    )
}

/// accessibility marker를 통해 `PerfCounters` counter 최신 값을 읽습니다.
/// marker가 없으면 `-1`을 반환합니다. 최신 값을 보장하려면 읽기 전에
/// state-change marker로 body re-render를 유도해야 합니다.
///
/// ## 사용 예시
/// ```swift
/// let count = readPerfCounter(slug: "home", key: "home.view.rebuild.proxy")
/// ```
public func readPerfCounter(slug: String, key: String) -> Int {
    let app = XCUIApplication()
    let prefix = "feature.\(slug).counter.\(key)."
    let query = app.descendants(matching: .any).matching(
        NSPredicate(format: "identifier BEGINSWITH %@", prefix)
    )
    for index in 0..<query.count {
        let identifier = query.element(boundBy: index).identifier
        if let suffix = identifier.components(separatedBy: prefix).last,
           let value = Int(suffix) {
            return value
        }
    }
    return -1
}

/// 기본 perf probe에서 사용하는 XCTest metric 묶음입니다.
public var defaultPerfMetrics: [XCTMetric] {
    [
        XCTClockMetric(),
        XCTMemoryMetric(),
        XCTCPUMetric()
    ]
}

/// Probe 전용 driver / marker sanity measurement에 맞춘 metric 묶음입니다.
/// XCUI tap synthesis, marker polling, accessibility synchronization, app/test process IPC가 포함되므로
/// authoritative UI Rendering metric으로 인용하지 않습니다.
public var actionLatencyMetrics: [XCTMetric] {
    [
        XCTClockMetric(),
        XCTCPUMetric()
    ]
}

public extension XCTestCase {
    /// Probe 전용 helper입니다.
    /// XCTest measurement overhead를 줄이기 위해 `measure(metrics:)` 한 iteration 안에서
    /// body를 여러 번 반복합니다.
    ///
    /// 측정값은 전체 반복의 bundle latency입니다. Action별 latency가 필요하면
    /// `repetitions`와 반복당 state change 수로 나눠야 합니다.
    /// 최종 rendering 비교에는 xctrace trace를 사용합니다.
    ///
    /// ## 사용 예시
    /// ```swift
    /// let app = XCUIApplication()
    /// measureActionLatency {
    ///     app.buttons["feature.home.perf.toast-show"].tap()
    /// }
    /// ```
    func measureActionLatency(
        metrics: [XCTMetric] = actionLatencyMetrics,
        repetitions: Int = 5,
        _ body: () -> Void
    ) {
        measure(metrics: metrics) {
            for _ in 0..<repetitions {
                body()
            }
        }
    }
}
