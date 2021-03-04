//
//  LDPageContainerViewControllerDataSource.swift
//  LDPageContainerViewController
//
//  Created by littledou on 2021/2/23.
//

import UIKit

// MARK: LDPageContainerViewController数据协议
public protocol LDPageContainerViewControllerDataSource: class {
    func numberOfViewControllers(in containerViewController: LDPageContainerViewController) -> NSInteger
    func viewController(at index: NSInteger, for containerViewController: LDPageContainerViewController) -> UIViewController
}
