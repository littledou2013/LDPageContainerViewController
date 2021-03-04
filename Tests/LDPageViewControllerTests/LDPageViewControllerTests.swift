import XCTest
@testable import LDPageViewController

final class LDPageViewControllerTests: XCTestCase, LDPageContainerViewControllerDelegate, LDPageContainerViewControllerDataSource {
    func numberOfViewControllers(in containerViewController: LDPageContainerViewController) -> NSInteger {
        3
    }
    
    func viewController(at index: NSInteger, for containerViewController: LDPageContainerViewController) -> UIViewController {
        UIViewController.init()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        var containerViewController: LDPageContainerViewController = LDPageContainerViewController.init()
        containerViewController.delegate = self
        containerViewController.dataSource = self
        containerViewController.pageScrollDirection = .horizontal
        containerViewController.register(classType: UIViewController.self, for: NSStringFromClass(UIViewController.self))
        containerViewController.reloadData(to: 0)
     //   XCTAssertEqual(LDPageViewController.text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
