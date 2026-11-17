import Foundation
import Testing

@testable import SubRadarCore

@Suite("ResourceBundleLocator")
struct ResourceBundleLocatorTests {
    @Test("资源包缺失时返回 nil 而不是崩溃")
    func missingBundleReturnsNil() {
        #expect(ResourceBundleLocator.locate(named: "NoSuchBundle_\(UUID().uuidString)") == nil)
    }

    @Test("可在 Contents/Resources 下找到资源包")
    func findsBundleInsideResources() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let app = root.appendingPathComponent("Fake.app/Contents")
        let bundleDir = app.appendingPathComponent("Resources/Fake_Res.bundle")
        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let main = try #require(Bundle(url: root.appendingPathComponent("Fake.app")))
        #expect(ResourceBundleLocator.locate(named: "Fake_Res", mainBundle: main) != nil)
    }
}
