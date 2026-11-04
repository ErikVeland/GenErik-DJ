import Foundation

@main
enum BrowserBaseline {
    static func main() {
        var failures = 0
        func expect(_ condition: Bool, _ message: String) {
            if !condition { failures += 1; print("FAIL: \(message)") }
        }
        var state = BrowserLayoutState(categoriesHidden: true)
        expect(state.detailHidden, "Songs opens without a detail column")
        state.showDetail()
        state.showCategories()
        expect(state.detailHidden, "Sources closes Details")
        state.showDetail()
        expect(state.categoriesHidden, "Details closes Sources")
        print("3 browser baseline checks; \(failures) failures")
        if failures > 0 { exit(1) }
    }
}
