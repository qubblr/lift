// Thanks to https://github.com/sshrpe/TDDSwiftPlayground
// Boilerplate to make the tests work:

import XCTest

class PlaygroundTestObserver : NSObject, XCTestObservation {
  @objc func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: UInt) {
    print("Test failed on line \(lineNumber): \(testCase.name), \(description)")
  }
}

let observer = PlaygroundTestObserver()
let center = XCTestObservationCenter.shared()
center.addTestObserver(observer)


struct TestRunner {
  
  func runTests(testClass:AnyClass) {
    print("Running test suite \(testClass)")
    let tests = testClass as! XCTestCase.Type
    let testSuite = tests.defaultTestSuite()
    testSuite.run()
    let run = testSuite.testRun as! XCTestSuiteRun
    
    print("Ran \(run.executionCount) tests in \(run.testDuration)s with \(run.totalFailureCount) failures")
  }
  
}

TestRunner().runTests(testClass: Tests.self)
