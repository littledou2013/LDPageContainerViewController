//
//  LDPageContainerViewControllerDelegate.swift
//  LDPageContainerViewController
//
//  Created by littledou on 2021/2/23.
//

import UIKit



// MARK: LDPageContainerViewController代理
public protocol LDPageContainerViewControllerDelegate: class {
    // 开始出现在界面上
    func containerViewController(_ containerViewController: LDPageContainerViewController, willBeginPagingAt page: (index: Int, viewController: UIViewController))
    
    // 静止并完全出现在界面上时
    func containerViewController(_ containerViewController: LDPageContainerViewController, didFinishPagingAt page: (index: Int, viewController: UIViewController))
    
    // 从界面上完全消失
    func containerViewController(_ containerViewController: LDPageContainerViewController, didEndPagingAt page: (index: Int, viewController: UIViewController))
    
    // 内容视图控制器的contentOffset已经变换了，注意后面会优化可能一样的都会回调
    func containerViewControllerDidScroll(_ containerViewController: LDPageContainerViewController)
    
    // 开始拖动，开始拖动到时候，可能刚好有两个页面在界面上
    func containerViewControllerWillBeginDragging(_ containerViewController: LDPageContainerViewController)
    
    // 拖动结束后停止滑动时回调，注意这时只会有一个子页面，可能有多个WillBeginDragging,但只有一个DidEndDragging，如缓冲滑动还没有结束，又开始滑动
    func containerViewControllerDidEndDragging(_ containerViewController: LDPageContainerViewController)
}

// MARK: LDPageContainerViewController代理默认实现
public extension LDPageContainerViewControllerDelegate {
    func containerViewController(_ containerViewController: LDPageContainerViewController, willBeginPagingAt page: (index: Int, viewController: UIViewController)) {
        
    }
    
    func containerViewController(_ containerViewController: LDPageContainerViewController, didFinishPagingAt page: (index: Int, viewController: UIViewController)) {
        
    }
    
    func containerViewController(_ containerViewController: LDPageContainerViewController, didEndPagingAt page: (index: Int, viewController: UIViewController)) {
        
    }
    
    func containerViewControllerDidScroll(_ containerViewController: LDPageContainerViewController) {
        
    }
    
    func containerViewControllerWillBeginDragging(_ containerViewController: LDPageContainerViewController) {
        
    }
    
    func containerViewControllerDidEndDragging(_ containerViewController: LDPageContainerViewController) {
        
    }
}
