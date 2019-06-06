//
//  CoreTextDemoTests.swift
//  CoreTextDemoTests
//
//  Created by guoyiyuan on 2018/11/29.
//  Copyright © 2018 guoyiyuan. All rights reserved.
//

import XCTest
@testable import CoreTextDemo

class CoreTextDemoTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
	
	func testAboutCTPath() {
		let rect = CGRect.init(origin: CGPoint.init(x: 300, y: 300), size: CGSize.init(width: 400, height: 400))
		let path = AboutCTPath(rect, path: nil, exclusionsPath: nil)
		XCTAssertNil(path, "转换不成功")
	}

}
