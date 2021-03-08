//
//  LDPageContainerViewController.swift
//  TestPageViewController
//
//  Created by littledou on 2021/1/8.
//
// swiftlint:disable all

import UIKit

public class LDPageContainerViewController: UIViewController {
    
    // MARK: 协议
    public weak var dataSource: LDPageContainerViewControllerDataSource?
    
    public weak var delegate: LDPageContainerViewControllerDelegate?
    
    public weak var prefetchDataSource: LDPageContainerViewControllerPrefetching?
    
    // MARK: 设置方向和自控制器个数
    /**
     滑动方向：支持横向和纵向
     .horizontal：横向滑动
     .vertical：纵向滑动
     */
    public enum LDPageScrollDirection {
        case horizontal
        case vertical
    }
    
    /**
     滑动方向，默认是横向滑动
     */
    public var pageScrollDirection: LDPageScrollDirection = .horizontal
    
    /**
    子控制器个数
    */
    private(set) var numbersOfViewControllers: Int = 0
    
    
    // TODO: 有待继续优化
    /**
     先开放，后期需要继续封装
     */
    public let scrollView: UIScrollView = {
        var scrollView = UIScrollView.init(frame: CGRect.zero)
        scrollView.isPagingEnabled = true
        scrollView.bounces = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        return scrollView
    }()
    
    public var isScrollEnabled: Bool {
        get {
            scrollView.isScrollEnabled
        }
        set {
            scrollView.isScrollEnabled = newValue
        }
    }
    
    public var bounces: Bool {
        get {
            scrollView.bounces
        }
        set {
            scrollView.bounces = newValue
        }
    }
    
    // MARK: 当前状态
    /**
     isTransiting:  是否正在滑动中，如果在滑动（手势触发的滑动、或者contentOffset:animated:true触发的滑动中）中，可能存在两个UIViewController可见
     index: 主UIViewController， 即最后调viewWillAppear控制器的index
     majorViewController:主UIViewController
     minorViewController: 如果在滑动中，会有另一个ViewController
     pagePercent: 属性pagePercent的值, 当前偏移量的比例，取值为 [0, numbers - 1]。
     */
    public var current: (isTransitioning: Bool, majorIndex: Int, majorViewController: UIViewController, minorIndex: Int?,  minorViewController: UIViewController?, pagePercent: CGFloat)? {
        if let majorChid = majorPage {
            return (self.isTransitioning, majorChid.index, majorChid.viewController, minorPage?.index, minorPage?.viewController, pagePercent)
        } else {
            return nil
        }
    }
    
    // TODO: 有待继续优化
    /**
     scrollView是否正在处于触摸过程中，这个有待继续优化
    */
    private var isTransitioning: Bool {
        scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating || animationCompletionBlock != nil
    }
    /**
     当前偏移量的比例，取值为 [0, numbers - 1]。
     算法 contentOffsetX / ( singlePageWidth)
     只读
     */
    private var pagePercent: CGFloat = 0.0
    
    /**
     主UIViewController， 只有一个视图控制器显示的时候，即为唯一显示字控制器信息， 如果同时出现两个视图控制的时候，一个的生命周期为viewWillAppear，一个生命周期为viewWillDisapper， 主子控制器为viewWillAppear生命周期的控制器
     */
    private var majorPage: (index: Int, viewController: UIViewController)?

    /**
     次UIViewController， 即生命周期为viewWillDisapper的子控制器
     */
    private var minorPage: (index: Int, viewController: UIViewController)?

    // MARK: 重用
    /**
    注册重用identifier
    */
    private var reuseIdentifiers = [String: Any]()
    /**
    可重用的控制器池
    */
    private var reusableViewControllers = [String: [UIViewController]]()
    
    
    // MARK:代码设置contentOffset
    /**
      手势触发的滑动过程中或者减速缓冲过程中，调用scrollView setContentOffset:animated:false，有一定概率会导致contentOffset有跳变效果，使用setContentOffsetStatus来强制避免跳变效果
     */
    private enum SetContentOffsetStatus {
        case none
        case isSetting(CGPoint)
        case setted(CGPoint)
    }
    private var setContentOffsetStatus = SetContentOffsetStatus.none
    
    /**
     在setContentOffset:animted调用前后设置，辅助参数，防止在设置contentOffset的时候调用didEndTransition方法
     */
    private var isContentOffsetSetting: Bool = false
    
    /**
       setContentOffset:animted:true方法设置的时候，scrollViewDidEndScrollingAnimation结束处理Block
     */
    private var animationCompletionBlock: ((_ finshed: Bool) -> Void)? = nil
    
    // MARK: 处理insert、delete、reload、move
    /**
       是否处于批处理insert、delete、reload、move块中
     */
    private var isBatchUpating = false
    
    /**
     批处理insert、delete、reload、move的辅助属性
     */
    private var batchUpdatingStatus:(majorViewController: UIViewController?, majorIndex: Int?, minorViewController: UIViewController?, minorIndex: Int?, contentOffset: CGFloat, pageWidth: CGFloat, numbers: Int) = (nil, nil, nil, nil, 0, 0, 0)
    
    // MARK: 生命周期
    public override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.delegate = self
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            self.automaticallyAdjustsScrollViewInsets = false
        }
        scrollView.frame = view.bounds
        view.addSubview(scrollView)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ld_AppearStatus = .willAppear
        updateSubViewControllerAppearStatus(animated)
        // 未显示状态调用layoutPageContainer是没有效果的，需要在viewWillAppear出现后调用一次，保证子控制器正确显示
        layoutPageContainer()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ld_AppearStatus = .didAppear
        updateSubViewControllerAppearStatus(animated)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        ld_AppearStatus = .willDisappear
        updateSubViewControllerAppearStatus(animated)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ld_AppearStatus = .didDisappear
        updateSubViewControllerAppearStatus(animated)
    }
    
    // 同步子ViewController的生命周期
    private func updateSubViewControllerAppearStatus(_ animated: Bool) {
        if minorPage == nil {
            if let majorPage = majorPage {
                updateLiftOfViewController(majorPage.viewController, to: ld_AppearStatus, animated: animated)
            }
        }
    }
    
    // 设置子ViewController的生命周期
    private func updateLiftOfViewController(_ viewController: UIViewController, to appearStatus: UIViewController.AppearStatus, animated: Bool) {
        if appearStatus == .none {
            viewController.updateLiftOfViewController(appearStatus: appearStatus, animated: animated)
        } else {
            if self.isDisppeared {
                viewController.updateLiftOfViewController(appearStatus: .didDisappear, animated: animated)
            } else if !self.isAppeared {
                if appearStatus != .didAppear {
                    viewController.updateLiftOfViewController(appearStatus: appearStatus, animated: animated)
                }
            } else {
                viewController.updateLiftOfViewController(appearStatus: appearStatus, animated: animated)
            }
        }
    }

    deinit { // 这行代码在后面调试方便的时候优化
        print("LDPageContainerViewController dealloc")
    }
    
    // MARK: 布局
    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if view.bounds == scrollView.frame {
            return
        } else { // 旋转、大小改变的时候处理
            scrollView.contentSize = CGSize.init(width: CGFloat.greatestFiniteMagnitude, height:  CGFloat.greatestFiniteMagnitude) // 先放大，防止调整大小的时候调scrollViewDidScroll
            scrollView.frame = view.bounds // 可能会导致scrollView的contentOffset变化，调用scrollViewDidScroll，但是先放大后就可以避免调用scrollViewDidScroll
            updateContentOffsetOfScrollView() // 调整contentOffset, 不会精确到之前的contentOffset，而是四舍五入到页面整数的contentOffset
            updateContentSizeOfScrollView() // 恢复contentSize
            layoutPageContainer() // 如果contentOffset为0， 则不会调用scrollViewDidScroll，不会对子viewController的位置进行更新，需要强制更新一次，但是改变size的时候，contentOffset为0的话会走layouSubviews来更新子childViewController的位置，但是如果contentOffset不为0，但是值没有变，则子viewController的位置不会更新，还是需要强制调用一次
        }
    }
    
    private func updateContentSizeOfScrollView() {
        let pageWidth = scrollView.bounds.size.width
        let pageHeight = scrollView.bounds.size.height
        let numbers = numbersOfViewControllers
        switch pageScrollDirection {
        case .horizontal:
            scrollView.contentSize = CGSize.init(width: pageWidth * CGFloat(numbers), height: pageHeight)
        case .vertical:
            scrollView.contentSize = CGSize.init(width: pageWidth, height: pageHeight * CGFloat(numbers))
        }
    }
    
    private func updateContentOffsetOfScrollView() {
        switch pageScrollDirection {
        case .horizontal:
            var contentOffsetX = round(pagePercent) * scrollView.bounds.size.width
            contentOffsetX = min(contentOffsetX, scrollView.contentSize.width - scrollView.bounds.size.width)
            contentOffsetX = max(contentOffsetX, 0)
            setContentOffsetStatus = .isSetting(CGPoint(x: contentOffsetX, y: 0))
            scrollView.setContentOffset(CGPoint(x: contentOffsetX, y: 0), animated: false)
            
        case .vertical:
            var contentOffsetY = round(pagePercent) * scrollView.bounds.size.height
            contentOffsetY = min(contentOffsetY, scrollView.contentSize.height - scrollView.bounds.size.height)
            contentOffsetY = max(contentOffsetY, 0)
            setContentOffsetStatus = .isSetting(CGPoint(x: 0, y: contentOffsetY))
            scrollView.setContentOffset(CGPoint(x: 0, y: contentOffsetY), animated: false)
            
        }
    }

    private func layoutPageContainer() {
        guard isDisppeared == false else {
            return
        }
        let pageWidth = scrollView.bounds.size.width
        let pageHeight = scrollView.bounds.size.height
        guard numbersOfViewControllers > 0, pageWidth > 0, pageHeight > 0 else {
            return
        }
        var minIndex: Int?
        var maxIndex: Int?
        var frame: ((NSInteger) -> CGRect)?
        let oldPagePercent = (majorPage == nil) ? nil : pagePercent
        switch pageScrollDirection {
        case .horizontal:
            let contentOffsetX = scrollView.contentOffset.x
            pagePercent = contentOffsetX / pageWidth
            minIndex = min(max(Int(floor(pagePercent)), 0), numbersOfViewControllers - 1) // 旋转的时候minIndexkennel会大于numbersOfViewControllers - 1
            maxIndex = max(min(Int(ceil(pagePercent)), numbersOfViewControllers - 1), 0)
            frame = { index -> CGRect in
                CGRect.init(x: pageWidth * CGFloat(index), y: 0, width: pageWidth, height: pageHeight)
            }
        case .vertical:
            let contentOffsetY = scrollView.contentOffset.y
            pagePercent = contentOffsetY / pageHeight
            frame = { index -> CGRect in
                CGRect.init(x:0 , y: pageHeight * CGFloat(index), width: pageWidth, height: pageHeight)
            }
            minIndex = min(max(Int(floor(pagePercent)), 0), numbersOfViewControllers - 1)
            maxIndex = max(min(Int(ceil(pagePercent)), numbersOfViewControllers - 1), 0)
        }
        if let minIndex = minIndex, let maxIndex = maxIndex, let frame = frame {
            
            // 更换viewController
            var oldVisibleViewControllers = [Int: UIViewController]() // 从展示到已经消失的
            var stillVisibleViewControllers = [Int: UIViewController]() // 仍然展示的
            if let majorPage = majorPage {
                oldVisibleViewControllers[majorPage.index] = majorPage.viewController
            }
            if let minorPage = minorPage {
                oldVisibleViewControllers[minorPage.index] = minorPage.viewController
            }
            var newVisibleViewControllers = [Int: UIViewController]() // 新展示的
            
            // 找到消失的、仍然存在的和即将显示的viewController
            for index in minIndex...maxIndex {
                if let viewController = oldVisibleViewControllers[index] {
                    stillVisibleViewControllers[index] = viewController
                    viewController.view.frame = frame(index) // 可能是大小变化或者rotate导致调用
                    oldVisibleViewControllers.removeValue(forKey: index)
                } else {
                    guard let viewController = dataSource?.viewController(at: index, for: self) else {
                        fatalError("dataSource 为nil 或者dataSource没有实现iewController(at: , for: )方法， dataSource = \(String(describing: dataSource))")
                    }
                    newVisibleViewControllers[index] = viewController
                }
            }
            
            // 做下UI是否正常判断
            guard oldVisibleViewControllers.count <= 2, oldVisibleViewControllers.count + stillVisibleViewControllers.count <= 2, stillVisibleViewControllers.count + newVisibleViewControllers.count <= 2,  newVisibleViewControllers.count <= 2 else {
                fatalError("控制器中的视图个数不对， 将要彻底消失 \(oldVisibleViewControllers.count)个，  \(oldVisibleViewControllers), 不应该超过2个, 仍然在的 \(stillVisibleViewControllers.count)个, \(stillVisibleViewControllers), 加上马上要出现的或者马上要消失的不能超过2个, 马上要出来的 \(newVisibleViewControllers.count)个, \(newVisibleViewControllers) , 不应该超过2个")
            }
            
            // 子UIViewController调整、delegate回调、生命周期更新
            for (index, viewController) in oldVisibleViewControllers {
                updateLiftOfViewController(viewController, to: .didDisappear, animated: self.isTransitioning)
                removeViewController((index, viewController), isTransitioning: self.isTransitioning)
            }
            
            for (index, viewController) in newVisibleViewControllers {
                updateLiftOfViewController(viewController, to: .none, animated: false)
                delegate?.containerViewController(self, willBeginPagingAt: (index: index, viewController: viewController))
                self.addChild(viewController)
                self.scrollView.addSubview(viewController.view)
                viewController.view.frame = frame(index)
                viewController.didMove(toParent: self)
            }
            delegate?.containerViewControllerDidScroll(self)
            if newVisibleViewControllers.count > 0 {
                if newVisibleViewControllers.count == 2 {
                    majorPage = nil
                    minorPage = nil
                    // 如果同时出现两个新的ViewController，随便选取其中一个作为主major，另一个作为minor
                    for (index, value) in newVisibleViewControllers {
                        if majorPage == nil {
                            majorPage = (index, value)
                            updateLiftOfViewController(value, to: .willAppear, animated: self.isTransitioning)
                        } else {
                            minorPage = (index, value)
                            updateLiftOfViewController(value, to: .willAppear, animated: self.isTransitioning)
                            updateLiftOfViewController(value, to: .willDisappear, animated: self.isTransitioning)
                        }
                        
                    }
                } else {
                    let add = newVisibleViewControllers.first!
                    majorPage = (add.key, add.value)
                    updateLiftOfViewController(add.value, to: .willAppear, animated: self.isTransitioning)
                    if let still = stillVisibleViewControllers.first {
                        minorPage = (still.key, still.value)
                        updateLiftOfViewController(still.value, to: .willDisappear, animated: self.isTransitioning)
                    } else {
                        minorPage = nil
                    }
                }
            } else {
                if stillVisibleViewControllers.count == 1 {
                    let only = stillVisibleViewControllers.first!
                    majorPage = (only.key, only.value)
                    minorPage = nil
                }
            }
            
            if prefetchDataSource != nil {
                if let oldPagePercent = oldPagePercent {
                    if oldPagePercent > pagePercent {
                        prefetchPages(currentScrollDirection: .small, pagePercent: pagePercent)
                    } else if (oldPagePercent == pagePercent) {
                        
                    } else {
                        prefetchPages(currentScrollDirection: .big, pagePercent: pagePercent)
                    }
                }
            }
        }
    }
    
    // MARK: 预取
    
    /**
       此时滑动方向
     */
    private enum CurrentScrollDirection {
        case none
        case big
        case small
    }
    
    /**
       预取数量
     */
    public var prefetchPageNumber: Int = 1 {
        didSet {
            prefetchVisibleRange = nil
        }
    }
    
    /**
       预取的页数
     */
    private var prefetchPages = Set<Int>()
    
    /**
       已预取范围
     */
    private var prefetchVisibleRange: (small: Int, big: Int, direction: CurrentScrollDirection)?
    private func prefetchPages(currentScrollDirection: CurrentScrollDirection, pagePercent: CGFloat) {
        if let prefetchDataSource = prefetchDataSource {
            let smallIndex = Int(floor(pagePercent))
            let bigIndex = Int(ceil(pagePercent))
            if let prefetchVisibleRange = prefetchVisibleRange, prefetchVisibleRange.small == smallIndex, prefetchVisibleRange.big == bigIndex, prefetchVisibleRange.direction == currentScrollDirection {
                return
            }
            prefetchVisibleRange = (smallIndex, bigIndex, currentScrollDirection)
            var start = max(smallIndex - prefetchPageNumber, 0)
            var end = min(bigIndex + prefetchPageNumber, numbersOfViewControllers - 1)
            var removePrefetchPages = prefetchPages
            var newPrefetchPages = Set<Int>()
            prefetchPages.removeAll()
            for index in start...end {
                if removePrefetchPages.contains(index) {
                    if index != smallIndex && index != bigIndex {
                        prefetchPages.insert(index)
                    }
                    removePrefetchPages.remove(index)
                }
            }
            
            switch currentScrollDirection {
            case .none:
                break
            case .big:
                start = smallIndex
                end = min(bigIndex + prefetchPageNumber, numbersOfViewControllers - 1)
            case .small:
                start = max(smallIndex - prefetchPageNumber, 0)
                end = bigIndex
            }
            
            for index in start...end {
                if !prefetchPages.contains(index) {
                    if index != smallIndex && index != bigIndex {
                        newPrefetchPages.insert(index)
                        prefetchPages.insert(index)
                    }
                    
                }
            }
            if removePrefetchPages.count > 0 || newPrefetchPages.count > 0 {
                prefetchDataSource.containerViewController(self, prefetchIndexes: newPrefetchPages, cancelPrefechIndexes: removePrefetchPages)
            }
            
        }
    }
    
    // MARK:Reuse
    /**
     注册使用 nib 初始化的控制器的重用标识

     @param class 控制器 class
     @param nibName 对应的nibName
     @param bundle nib对应的bundle
     @param identifier 对应的重用标识
     */
    public func register(classType: AnyClass, nibName: String, bundle: Bundle?, for reuseIdentifier: String) {
        reuseIdentifiers[reuseIdentifier] = ["classType":classType,"nibName": nibName, "bundle": bundle ?? NSNull.init()]
    }
    
    /**
     注册 Class 为控制器的重用标识

     @param class 对应的Class
     @param identifier 对应的重用标识
     */
    public func register(classType: AnyClass, for reuseIdentifier: String) {
        reuseIdentifiers[reuseIdentifier] = classType
    }
    
    /**
     根据重用标识获取一个控制器

     @param identifier 对应的identifier
     @return 重用的控制器，如果对应的identifier未被注册，则返回 nil；如果不存在对应可重用的控制器，则会自动创建一个控制器并返回。
     */
    public func dequeueReusableViewController(with identifier: String) -> UIViewController {
        guard let identifierClass = reuseIdentifiers[identifier] else {
            fatalError("\(identifier) not Registered for \(self)")
        }
        if let viewController = popFromCachedViewControllers(with: identifier) {
            viewController.ld_pagePrepareForReuse()
            viewController.ld_reusableIdentifier = identifier
            return viewController
        }
        
        if let nibDic = identifierClass as? [String: Any] {
            if let classType = nibDic["classType"] as? UIViewController.Type, let nibName = nibDic["nibName"] as? String {
                let bundle = nibDic["bundle"] as? Bundle
                let viewController = classType.init(nibName: nibName,  bundle: bundle)
                viewController.ld_pagePrepareForReuse()
                viewController.ld_reusableIdentifier = identifier
                return viewController
            }
        } else {
            if let classType = identifierClass as? UIViewController.Type {
                let viewController = classType.init()
                viewController.ld_pagePrepareForReuse()
                viewController.ld_reusableIdentifier = identifier
                return viewController
            }
        }
        fatalError("\(identifier) registered has a error for \(self)")
    }

    private func pushToCachedViewControllers(with viewController: UIViewController) -> Bool {
        if let identifier = viewController.ld_reusableIdentifier, reuseIdentifiers.keys.contains(identifier) {
            var viewControllers = reusableViewControllers[identifier] ?? []
            viewControllers.append(viewController)
            reusableViewControllers[identifier] = viewControllers
            return true
        }
        return false
    }
    
    private func popFromCachedViewControllers(with identifier: String) -> UIViewController? {
        guard var viewControllers = reusableViewControllers[identifier], viewControllers.count > 0 else {
            return nil
        }
        let viewController = viewControllers.first
        viewControllers.remove(at: 0)
        reusableViewControllers[identifier] = viewControllers
        return viewController
    }
    
    // MARK: 辅助方法
    private func removeViewController(_ page: (index: Int, viewController: UIViewController)?, isTransitioning: Bool = false) {
        if let page = page {
            page.viewController.willMove(toParent: nil)
            page.viewController.view.removeFromSuperview()
            page.viewController.removeFromParent()
            updateLiftOfViewController(page.viewController, to: .didDisappear, animated: isTransitioning)
            delegate?.containerViewController(self, didEndPagingAt: (index: page.index, viewController: page.viewController))
            _ = pushToCachedViewControllers(with: page.viewController)
        }
    }


    // MARK: 滑动结束、设置contentOffset结束一定要回调这个方法，否则生命周期会出现问题
    
    /// 注意这里的参数很重要
    /// - Parameters:
    ///   - fromDragging: 是否从scrollView的回调函数里调用的，fromDragging = true，并不代表手势触摸过程已经结束，为false的时候表示是代码设置contentOffset的调用
    private func didEndTransition(fromDragging: Bool = false) {
        if isTransitioning == false, isDisppeared == false, isContentOffsetSetting == false { // 为什么要加isDisppeared == false， 因为scroll(to, animated, completion)调用的时候状态可能是isDisppeared
            guard let only = majorPage else {
                fatalError("不对 majorPage = \(String(describing:majorPage)), monirPage = \(String(describing: minorPage))")
            }
            if fromDragging {
                delegate?.containerViewControllerDidEndDragging(self)
            }
            updateLiftOfViewController(only.viewController, to: .didAppear, animated: isTransitioning)
            delegate?.containerViewController(self, didFinishPagingAt: (index: only.index, viewController: only.viewController))
            setContentOffsetStatus = .none
        }
    }
        
    // MARK: 子viewController生命周期的管理
    public override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        return false
    }
    
    // MARK: 内存释放
    public override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        reusableViewControllers.removeAll()
    }
    
    
}

extension LDPageContainerViewController {
    // MARK:load
    public func insert(at indexes: [Int]) {
        if isBatchUpating == false {
            let oldNumbers = numbersOfViewControllers
            let newNumbers = dataSource?.numberOfViewControllers(in: self) ?? 0
            guard oldNumbers + indexes.count == newNumbers else {
                fatalError("insert 数据不匹配")
            }
            numbersOfViewControllers = newNumbers
            var oldContentOffset = scrollView.contentOffset.x
            var pageWidth = scrollView.bounds.size.width
            if pageScrollDirection == .vertical {
                oldContentOffset = scrollView.contentOffset.y
                pageWidth = scrollView.bounds.size.height
            }
            for index in indexes {
                if CGFloat(index) < oldContentOffset {
                    oldContentOffset += pageWidth
                }
                if let majorIndex = majorPage?.index, index < majorIndex {
                    majorPage?.index = majorIndex + 1
                }
                
                if let minorIndex = minorPage?.index, index < minorIndex {
                    minorPage?.index = minorIndex + 1
                }
            }
            layoutPageContainer()
            didEndTransition()
        } else {
            for index in indexes {
                if CGFloat(index) < batchUpdatingStatus.contentOffset {
                    batchUpdatingStatus.contentOffset += batchUpdatingStatus.pageWidth
                }
                if let majorIndex = batchUpdatingStatus.majorIndex, index < majorIndex {
                    batchUpdatingStatus.majorIndex = majorIndex + 1
                }
                
                if let minorIndex = batchUpdatingStatus.minorIndex, index < minorIndex {
                    batchUpdatingStatus.minorIndex = minorIndex + 1
                }
            }
            batchUpdatingStatus.numbers += indexes.count
        }
    }
    
    public func delete(at indexes: [Int]) {
        if isBatchUpating == false {
            let oldNumbers = numbersOfViewControllers
            let newNumbers = dataSource?.numberOfViewControllers(in: self) ?? 0
            guard oldNumbers == newNumbers + indexes.count else {
                fatalError("delete 数据不匹配")
            }
            numbersOfViewControllers = newNumbers
            var oldContentOffset = scrollView.contentOffset.x
            var pageWidth = scrollView.bounds.size.width
            if pageScrollDirection == .vertical {
                oldContentOffset = scrollView.contentOffset.y
                pageWidth = scrollView.bounds.size.height
            }
            for index in indexes {
                if CGFloat(index) < oldContentOffset {
                    oldContentOffset -= pageWidth
                }
                if let majorIndex = majorPage?.index {
                    if index == majorIndex {
                        majorPage = nil
                    } else if index < majorIndex {
                        majorPage?.index = majorIndex - 1
                    }
                }
                
                if let minorIndex = minorPage?.index, index < minorIndex {
                    if index == minorIndex {
                        minorPage = nil
                    } else if index < minorIndex {
                        minorPage?.index = minorIndex - 1
                    }
                }
            }
            layoutPageContainer()
            didEndTransition()
        } else {
            for index in indexes {
                if CGFloat(index) < batchUpdatingStatus.contentOffset {
                    batchUpdatingStatus.contentOffset -= batchUpdatingStatus.pageWidth
                }
                if let majorIndex = batchUpdatingStatus.majorIndex, index < majorIndex {
                    if index == majorIndex {
                        batchUpdatingStatus.majorViewController = nil
                        batchUpdatingStatus.majorIndex = nil
                    } else if index < majorIndex {
                        batchUpdatingStatus.majorIndex = majorIndex - 1
                    }
                }
                
                if let minorIndex = batchUpdatingStatus.minorIndex, index < minorIndex {
                    if index == minorIndex {
                        batchUpdatingStatus.minorViewController = nil
                        batchUpdatingStatus.minorIndex = nil
                    } else if index < minorIndex {
                        batchUpdatingStatus.minorIndex = minorIndex - 1
                    }
                }
            }
            batchUpdatingStatus.numbers -= indexes.count
        }
    }
    
    public func reload(at indexes: [Int]) {
        if isBatchUpating == false {
            for index in indexes {
                if let majorIndex = majorPage?.index, index == majorIndex {
                    majorPage = nil
                }
                
                if let minorIndex = minorPage?.index, index == minorIndex {
                    minorPage = nil
                }
            }
            layoutPageContainer()
            didEndTransition()
        } else {
            for index in indexes {
                if let majorIndex = batchUpdatingStatus.majorIndex, index == majorIndex {
                    batchUpdatingStatus.majorViewController = nil
                    batchUpdatingStatus.majorIndex = nil
                }
                
                if let minorIndex = batchUpdatingStatus.minorIndex, index == minorIndex {
                    batchUpdatingStatus.minorViewController = nil
                    batchUpdatingStatus.minorIndex = nil
                }
            }
        }
    }
    
    public func move(at index: Int, to newIndex: Int) {
        if isBatchUpating == false {
            if let major = majorPage, major.index == index {
                if let minor = minorPage, minor.index > major.index, minor.index < newIndex {
                    minorPage?.index -= 1
                }
                majorPage?.index = newIndex
            }
            
            if let minor = minorPage, minor.index == index {
                if let major = majorPage, major.index > minor.index, major.index < newIndex {
                    majorPage?.index -= 1
                }
                minorPage?.index = newIndex
            }
            layoutPageContainer()
            didEndTransition()
        } else {
            if let majorIndex = batchUpdatingStatus.majorIndex, majorIndex == index {
                if let minorIndex = batchUpdatingStatus.minorIndex, minorIndex > majorIndex, minorIndex < newIndex {
                    batchUpdatingStatus.minorIndex = minorIndex - 1
                }
                batchUpdatingStatus.majorIndex = newIndex
            }
            
            if let minorIndex = batchUpdatingStatus.minorIndex, minorIndex == index {
                if let majorIndex = batchUpdatingStatus.majorIndex, majorIndex > minorIndex, majorIndex < newIndex {
                    batchUpdatingStatus.majorIndex = majorIndex - 1
                }
                batchUpdatingStatus.minorIndex = newIndex
            }
        }
    }
    
    func perform(batchUpdates:  (() -> Void)? = nil, completion: ((_ finshed: Bool) -> Void)? = nil) {
        isBatchUpating = true
        var contentOffset = scrollView.contentOffset.x
        var pageWidth = scrollView.bounds.size.width
        if pageScrollDirection == .vertical {
            contentOffset = scrollView.contentOffset.y
            pageWidth = scrollView.bounds.size.height
        }
        batchUpdatingStatus = (current?.majorViewController, current?.minorIndex, current?.minorViewController, current?.minorIndex, contentOffset, pageWidth, numbersOfViewControllers)
        if let batchUpdates = batchUpdates {
            batchUpdates()
        }
        let newNumbers = dataSource?.numberOfViewControllers(in: self) ?? 0
        guard batchUpdatingStatus.numbers == newNumbers else {
            fatalError("数据不匹配")
        }
        layoutPageContainer()
        didEndTransition()
        if let completion = completion {
            completion(true)
        }
        isBatchUpating = false
    }
    
    public func slientAppend(completion: ((_ finshed: Bool) -> Void)? = nil) {
        let numbers = dataSource?.numberOfViewControllers(in: self) ?? 0
        guard numbers > numbersOfViewControllers else {
            print("slientAppend numberOfViewControllers应该更大")
            if let completion = completion {
                completion(false)
            }
            return
        }
        numbersOfViewControllers = numbers
        updateContentSizeOfScrollView()
    }
    
    public func reloadData() {
        reloadData(to: 0, forceRefresh: true, completion: nil)
    }
    
    /**
     重新加载所有子视图控制器数据，并且切换到 index 所在的页面
     @param index 目标索引, 如果index不合法（合法：index >== 0 && index < 页数)，则不做任何事， index没传，则取当前contentOffset，如果contentOffset不合法（如大于新的numberOfViewControllers * width - width),也不做任何事
     @param forceRefresh 是否强制刷新子页面
     @param completion 完成后回调
     */
    public func reloadData(to index: Int?, forceRefresh: Bool = true, completion: ((_ finshed: Bool) -> Void)? = nil) {
        print("littledou function")
        print(#function)
        print(index ?? "")
        let numbers = dataSource?.numberOfViewControllers(in: self) ?? 0
        guard numbers > 0 else {
            print("reloadData numberOfViewControllers为0")
            if let completion = completion {
                completion(false)
            }
            return
        }
        if let index = index {
            guard index >= 0, index < numbers else {
                print("reloadData index不合规范")
                if let completion = completion {
                    completion(false)
                }
                return
            }
        } else {
            let maxX = (CGFloat((numbers - 1)) * scrollView.bounds.size.width + scrollView.contentInset.left)
            let maxY = (CGFloat((numbers - 1)) * scrollView.bounds.size.height + scrollView.contentInset.bottom)
            guard scrollView.contentOffset.x <= maxX && scrollView.contentOffset.y <= maxY else {
                print("reloadData contentOffset不合规范")
                if let completion = completion {
                    completion(false)
                }
                return
            }
        }
        
        if forceRefresh {
            removeViewController(majorPage)
            removeViewController(minorPage)
            majorPage = nil
            minorPage = nil
        }
        
        numbersOfViewControllers = numbers
        prefetchPages.removeAll()
    
        scrollView.contentSize = CGSize.init(width: CGFloat.greatestFiniteMagnitude, height:  CGFloat.greatestFiniteMagnitude) // 先放大，防止调整大小的时候调scrollViewDidScroll
        // 这里可能会回调scrollViewDidScroll，会是一个坑，如果contentSize的大小小于contentOffset，就会导致scrollViewDidScroll
        privateScroll(to: index, animated: false, completion: completion)
        updateContentSizeOfScrollView()
    }
    
    private func privateScroll(to index: Int?, animated: Bool = false, completion: ((_ finshed: Bool) -> Void)? = nil) {
        if let index = index {
            if let majorPage = majorPage, minorPage == nil, majorPage.index == index { // 刚好在当前页面，不做任何事情
                prefetchPages(currentScrollDirection: .none, pagePercent: CGFloat(index))
                if let completion = completion {
                    completion(true)
                }
                return
            }
            
            if scrollView.isTracking, animated { // 在由手势引起的滑动过程中，不允许动态设置contentOffset
                // 如果有动画，在触摸的同时调用该方法，触摸不动，会动画到指定的contentOffset，触摸重新动，contentOffset会回到触摸动之前的值
                if let completion = completion {
                    completion(false)
                }
                return
            }
            
            var hasChanged = true
            var contentOffset = scrollView.contentOffset
            switch pageScrollDirection {
            case .horizontal:
                contentOffset.x = CGFloat(index) * scrollView.bounds.size.width
                if contentOffset.x == scrollView.contentOffset.x {
                    hasChanged = false
                }
            case .vertical:
                contentOffset.y = CGFloat(index) * scrollView.bounds.size.height
                if contentOffset.y == scrollView.contentOffset.y {
                    hasChanged = false
                }
            }
            
            // 当contentOffset没有变化是不会调用didScroll或者didEndAnimation
            if hasChanged == false {
                if majorPage == nil {
                    layoutPageContainer()
                    didEndTransition(fromDragging: false)
                }
                prefetchPages(currentScrollDirection: .none, pagePercent: CGFloat(index))
                if let completion = completion {
                    completion(true)
                }
                return
            }
            
            if animated == false {
                setContentOffsetStatus = .isSetting(contentOffset)
            }
            isContentOffsetSetting = true
            scrollView.setContentOffset(contentOffset, animated: animated)
            isContentOffsetSetting = false
            
            if animated == false {
                didEndTransition(fromDragging: false)
                prefetchPages(currentScrollDirection: .none, pagePercent: CGFloat(index))
                if let completion = completion {
                    completion(true)
                }
            } else {
                animationCompletionBlock = {[weak self] finshed in
                    if let self = self  {
                        if self.scrollView.contentOffset == contentOffset {
                            self.didEndTransition(fromDragging: false)
                            if let completion = completion {
                                completion(finshed)
                            }
                        } else {
                            if let completion = completion {
                                completion(false)
                            }
                        }
                    }
                }
            }
        } else {
            layoutPageContainer()
            if minorPage == nil {
                didEndTransition(fromDragging: false)
            }
            
            prefetchPages(currentScrollDirection: .none, pagePercent: pagePercent)
            if let completion = completion {
                completion(true)
            }
            return
        }
    }
    
    public func scroll(to index: Int, animated: Bool = false, completion: ((_ finshed: Bool) -> Void)? = nil) {
        guard index >= 0, index < numbersOfViewControllers else {
            print("scroll to index不合规范")
            if let completion = completion {
                completion(false)
            }
            return
        }
        privateScroll(to: index, animated: animated, completion: completion)

    }
}


extension LDPageContainerViewController {
    /**
     当前偏移量占总偏移量的比例，取值为 [0,1]。
     算法 contentOffsetX / (totalContentSizeWidth - singlePageWidth)
     */
    public func corvertInTotal(from pagePercent:CGFloat) -> CGFloat? {
        switch pageScrollDirection {
        case .horizontal:
            let bottomFactor = scrollView.contentSize.width  - scrollView.bounds.size.width
            if bottomFactor > 0  {
                return pagePercent * scrollView.bounds.size.width / bottomFactor
            }
        case .vertical:
            let bottomFactor = scrollView.contentSize.height - scrollView.bounds.size.height
            if bottomFactor > 0 {
                return pagePercent * scrollView.bounds.size.height / bottomFactor
            }
        }
        return nil
    }
}

extension LDPageContainerViewController: UIScrollViewDelegate {
    // MARK: UIScrollViewDelegate
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.containerViewControllerWillBeginDragging(self)
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        switch setContentOffsetStatus {
        case .isSetting(let contentOffset): //   // 外界设置contentOffset的时候，第一次调用的scrollView的contentOffset是对的
            if scrollView.isTracking {
                setContentOffsetStatus = .setted(contentOffset)
            } else {
                setContentOffsetStatus = .none
            }
        case .setted(let contentOffset): // // 外界设置contentOffset的时候，第二次调用的scrollView的contentOffset是可能是不对的，需要做一次矫正，为什么一定要在第二次的时候矫正，如果在第一次调用的时候矫正，是不起作用的
            setContentOffsetStatus = .none
            scrollView.setContentOffset(contentOffset, animated: false)
            return
        case .none:
            break
        }
        layoutPageContainer()
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.didEndTransition(fromDragging: true)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.didEndTransition(fromDragging: true)
        }
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if let animationBlock = animationCompletionBlock {
            animationCompletionBlock = nil
            animationBlock(true)
        }
    }
}
