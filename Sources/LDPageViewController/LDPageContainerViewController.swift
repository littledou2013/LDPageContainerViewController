//
//  LDPageContainerViewController.swift
//  TestPageViewController
//
//  Created by littledou on 2021/1/8.
//

import UIKit

class LDPageContainerViewController: UIViewController, UIScrollViewDelegate {
    
    weak var dataSource: LDPageContainerViewControllerDataSource?
    
    weak var delegate: LDPageContainerViewControllerDelegate?
    
    weak var prefetchDataSource: LDPageContainerViewControllerPrefetching?
    
    /**
     滑动方向：支持横向和纵向
     .horizontal：横向滑动
     .vertical：纵向滑动
     */
    enum LDPageScrollDirection {
        case horizontal
        case vertical
    }
    
    /**
     滑动方向，默认是横向滑动
     */
    var pageScrollDirection: LDPageScrollDirection = .horizontal
    
    /**
     先开放，后期需要继续封装
     */
    let scrollView: UIScrollView = {
        var scrollView = UIScrollView.init(frame: CGRect.zero)
        scrollView.isPagingEnabled = true
        scrollView.bounces = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        return scrollView
    }()
    
    var isScrollEnabled: Bool {
        get {
            scrollView.isScrollEnabled
        }
        set {
            scrollView.isScrollEnabled = newValue
        }
    }
    
    var bounces: Bool {
        get {
            scrollView.bounces
        }
        set {
            scrollView.bounces = newValue
        }
    }
    
    /**
    子控制器个数
    */
    private(set) var numbersOfViewControllers: Int = 0
    
    /**
     isTransiting:  是否正在滑动中，如果在滑动（手势触发的滑动、或者contentOffset:animated:true触发的滑动中）中，可能存在两个UIViewController可见
     index: 主UIViewController， 即最后调viewWillAppear控制器的index
     majorViewController:主UIViewController
     minorViewController: 如果在滑动中，会有另一个ViewController
     pagePercent: 属性pagePercent的值, 当前偏移量的比例，取值为 [0, numbers - 1]。
     */
    
    var current: (isTransitioning: Bool, index: Int, majorViewController: UIViewController,  minorViewController: UIViewController?, pagePercent: CGFloat)? {
        if let majorChid = majorPage {
            return (self.isTransitioning, majorChid.index, majorChid.viewController, minorPage?.viewController, pagePercent)
        } else {
            return nil
        }
    }
    
    /**
     scrollView是否正在处于触摸过程中
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
     主UIViewController， 只有一个视图控制器显示的时候，即为唯一显示字控制器信息， 如果同时出现两个视图控制的时候，一个的生命周期为viewWillAppear，一个生命周期为viewWillDisapper， 主子控制器为viewWillAppear生命周期的控制器，也可能出现两个ViewController都处于viewWillAppear状态的，第一个调viewWillAppear的viewController为majorPage，另一个则为minorPage
     */
    private var majorPage: (index: Int, viewController: UIViewController)?

    /**
     次UIViewController， 即生命周期为viewWillDisapper的子控制器, 也可能出现两个ViewController都处于viewWillAppear状态的，第一个调viewWillAppear的viewController为majorPage，另一个则为minorPage
     */
    private var minorPage: (index: Int, viewController: UIViewController)?

    /**
    注册重用identifier
    */
    private var reuseIdentifiers = [String: Any]()
    /**
    可重用的控制器池
    */
    private var reusableViewControllers = [String: [UIViewController]]()
    
    
    /**
     可重用的控制器池
      手势触发的滑动过程中或者减速缓冲过程中，调用scrollView setContentOffset:animated:false，有一定概率会导致contentOffset有跳变效果，使用setContentOffsetStatus来强制避免跳变效果
     */
    private enum SetContentOffsetStatus {
        case none
        case isSetting(CGPoint)
        case setted(CGPoint)
    }
    private var setContentOffsetStatus = SetContentOffsetStatus.none
    
    /**
     在setContentOffset:animted调用前后设置，辅助参数
     */
    private var isContentSetting: Bool = false
    
    // MARK: 生命周期
    override func viewDidLoad() {
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ld_AppearStatus = .willAppear
        updateSubViewControllerAppearStatus(animated)
        // 未显示状态调用layoutPageContainer是没有效果的，需要在viewWillAppear出现后调用一次，保证子控制器正确显示
        layoutPageContainer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ld_AppearStatus = .didAppear
        updateSubViewControllerAppearStatus(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        ld_AppearStatus = .willDisappear
        updateSubViewControllerAppearStatus(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        ld_AppearStatus = .didDisappear
        updateSubViewControllerAppearStatus(animated)
    }
    
    // 同步子ViewController的生命周期
    private func updateSubViewControllerAppearStatus(_ animated: Bool) {
        guard isTransitioning == false else { // 正在滑动中不处理
            return
        }
        guard minorPage == nil else {
            fatalError("\(self) 滑动停止的时候，应该正好只有一个majorViewController或者没有: current = \(String(describing: current))")
        }
        
        if let majorPage = majorPage {
            updateLiftOfViewController(majorPage.viewController, to: ld_AppearStatus, animated: animated)
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
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if view.bounds == scrollView.frame {
            return
        } else {
            scrollView.contentSize = CGSize.init(width: CGFloat.greatestFiniteMagnitude, height:  CGFloat.greatestFiniteMagnitude) // 先放大，防止调整大小的时候调scrollViewDidScroll
            scrollView.frame = view.bounds // 可能会导致scrollView的contentOffset变化，调用scrollViewDidScroll，但是先放大后就可以避免调用scrollViewDidScroll
            updateContentOffsetOfScrollView() // 调整contentOffset
            updateContentSizeOfScrollView() // 恢复contentSize
            layoutPageContainer() // 如果contentOffset为0， 则不会调用scrollViewDidScroll，不会对子viewController的位置进行更新，需要强制更新一次，但是改变size的时候，contentOffset为0的话会走layouSubviews来更新子childViewController的位置，但是如果contentOffset不为0，但是值没有变，则子viewController的位置不会更新，还是需要强制调用一次
        }
    }
    
    func updateContentSizeOfScrollView() {
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
    
    func updateContentOffsetOfScrollView() {
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
            
            // 子UIVieweController调整、delegate回调、生命周期更新
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
                        } else {
                            minorPage = (index, value)
                        }
                        updateLiftOfViewController(value, to: .willAppear, animated: self.isTransitioning)
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
    private enum CurrentScrollDirection {
        case none
        case big
        case small
    }
    var prefetchPageNumber: Int = 1 {
        didSet {
            prefetchVisibleRange = nil
        }
    }
    private var prefetchPages = Set<Int>()
    private var prefetchVisibleRange: (small: Int, big: Int)?
    private func prefetchPages(currentScrollDirection: CurrentScrollDirection, pagePercent: CGFloat) {
        if let prefetchDataSource = prefetchDataSource {
            let smallIndex = Int(floor(pagePercent))
            let bigIndex = Int(ceil(pagePercent))
            if let prefetchVisibleRange = prefetchVisibleRange, prefetchVisibleRange.small == smallIndex, prefetchVisibleRange.big == bigIndex {
                return
            }
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
    func register(classType: AnyClass, nibName: String, bundle: Bundle?, for reuseIdentifier: String) {
        reuseIdentifiers[reuseIdentifier] = ["classType":classType,"nibName": nibName, "bundle": bundle ?? NSNull.init()]
    }
    
    /**
     注册 Class 为控制器的重用标识

     @param class 对应的Class
     @param identifier 对应的重用标识
     */
    func register(classType: AnyClass, for reuseIdentifier: String) {
        reuseIdentifiers[reuseIdentifier] = classType
    }
    
    /**
     根据重用标识获取一个控制器

     @param identifier 对应的identifier
     @return 重用的控制器，如果对应的identifier未被注册，则返回 nil；如果不存在对应可重用的控制器，则会自动创建一个控制器并返回。
     */
    func dequeueReusableViewController(with identifier: String) -> UIViewController {
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

    // MARK:load
    /**
       setContentOffset:animted:true方法设置的时候，scrollViewDidEndScrollingAnimation结束处理Block
     */
    private var animationCompletionBlock: ((_ finshed: Bool) -> Void)? = nil
    
    /**
     重新加载所有子视图控制器数据，并定位到0
     */
    func reloadData(completion: ((_ finshed: Bool) -> Void)? = nil) {
        reloadData(to: 0, completion: completion)
    }

    /**
     重新加载所有子视图控制器数据，并且切换到 index 所在的页面
     @param index 目标索引, 如果index不合法（合法：index >== 0 && index < 页数)，则不做任何事
     */
    func reloadData(to index: Int, completion: ((_ finshed: Bool) -> Void)? = nil) {
        let numbers = dataSource?.numberOfViewControllers(in: self) ?? 0
        guard index >= 0, index < numbers else {
            if let completion = completion {
                print("页数不和规范")
                completion(false)
            }
            return
        }
        removeViewController(majorPage)
        removeViewController(minorPage)
        numbersOfViewControllers = dataSource?.numberOfViewControllers(in: self) ?? 0
        prefetchPages.removeAll()
        updateContentSizeOfScrollView() // 这里可能会回调scrollViewDidScroll，会是一个坑，如果contentSize的大小小于contentOffset，就会导致scrollViewDidScroll
        scroll(to: index, animated: false, completion: completion)
    }
    
    func scroll(to index: Int, animated: Bool, completion: ((_ finshed: Bool) -> Void)? = nil) {
        guard index >= 0, index < numbersOfViewControllers else {
            print("index不和规范")
            if let completion = completion {
                completion(false)
            }
            return
        }
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
            prefetchPages(currentScrollDirection: .none, pagePercent: CGFloat(index))
            if let completion = completion {
                completion(true)
            }
            return
        }
        
        if animated == false {
            setContentOffsetStatus = .isSetting(contentOffset)
        }
        isContentSetting = true
        scrollView.setContentOffset(contentOffset, animated: animated)
        isContentSetting = false
        
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
    }
    
    // MARK: UIScrollViewDelegate
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        delegate?.containerViewControllerWillBeginDragging(self)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
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
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.didEndTransition(fromDragging: true)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.didEndTransition(fromDragging: true)
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if let animationBlock = animationCompletionBlock {
            animationCompletionBlock = nil
            animationBlock(true)
        }
    }
    
    /// 注意这里的参数很重要
    /// - Parameters:
    ///   - fromDragging: 是否从scrollView的回调函数里调用的，fromDragging = true，并不代表手势触摸过程已经结束，为false的时候表示是代码设置contentOffset的调用
    private func didEndTransition(fromDragging: Bool = false) {
        if isTransitioning == false, isDisppeared == false, isContentSetting == false { // 为什么要加isDisppeared == false， 因为scroll(to, animated, completion)调用的时候状态可能是isDisppeared
            guard let only = majorPage, minorPage == nil else {
                fatalError("不对 majorPage = \(String(describing:majorPage)), monirPage = \(String(describing: minorPage))")
            }
            if fromDragging {
                delegate?.containerViewControllerDidEndDragging(self)
            }
            updateLiftOfViewController(only.viewController, to: .didAppear, animated: isTransitioning)
            delegate?.containerViewController(self, didFinishPagingAt: (index: only.index, viewController: only.viewController))
            setContentOffsetStatus = .none
            animationCompletionBlock = nil
            
        }
    }
        
    // MARK: 子viewController生命周期的管理
    override var shouldAutomaticallyForwardAppearanceMethods: Bool {
        return false
    }
    
    // MARK: 内存释放
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        reusableViewControllers.removeAll()
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
}

extension LDPageContainerViewController {
    /**
     当前偏移量占总偏移量的比例，取值为 [0,1]。
     算法 contentOffsetX / (totalContentSizeWidth - singlePageWidth)
     */
    func corvertInTotal(from pagePercent:CGFloat) -> CGFloat? {
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
