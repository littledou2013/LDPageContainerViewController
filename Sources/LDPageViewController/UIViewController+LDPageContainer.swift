//
//  UIViewController+LDPageContainer.swift
//  LDPageContainer
//
//  Created by littledou on 2021/2/23.
//

import Foundation

import UIKit

// MARK: UIViewController扩展
extension UIViewController {
    // 嵌套结构体
       private struct LDPageContainerAssociatedKeys {
           static var appearStatusKey = "appearStatusKey"
           static var reusableIdentiferKey = "reusableIdentiferKey"
       }
       
    
     var ld_reusableIdentifier: String? {
        get {
            return objc_getAssociatedObject(self, &LDPageContainerAssociatedKeys.reusableIdentiferKey) as? String
        }
        set {
            objc_setAssociatedObject(self, &LDPageContainerAssociatedKeys.reusableIdentiferKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
    
    func ld_pagePrepareForReuse() {
        
    }
    
    var ld_AppearStatus: AppearStatus {
        get {
            return objc_getAssociatedObject(self, &LDPageContainerAssociatedKeys.appearStatusKey) as? AppearStatus ?? .none
        }
        set {
            objc_setAssociatedObject(self, &LDPageContainerAssociatedKeys.appearStatusKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func updateLiftOfViewController(appearStatus: AppearStatus, animated: Bool) {
        let oldAppearStatus = self.ld_AppearStatus
        if oldAppearStatus == appearStatus {
            return
        }
        self.ld_AppearStatus = appearStatus
        switch self.ld_AppearStatus {
        case .none:
            break
        case .willAppear:
            self.beginAppearanceTransition(true, animated: animated)
        case .didAppear:
            if oldAppearStatus == .willAppear {
                self.endAppearanceTransition()
            } else {
                self.beginAppearanceTransition(true, animated: animated)
                self.endAppearanceTransition()
            }
        case .willDisappear:
            self.beginAppearanceTransition(false, animated: animated)
        case .didDisappear:
            if oldAppearStatus == .none {
                return
            }
            if oldAppearStatus == .willDisappear {
                self.endAppearanceTransition()
            } else {
                self.beginAppearanceTransition(false, animated: animated)
                self.endAppearanceTransition()
            }
        }
    }
    
    enum AppearStatus {
        case none
        case willAppear
        case didAppear
        case willDisappear
        case didDisappear
    }
    
    var isAppeared: Bool {
        return ld_AppearStatus == .didAppear
    }
    
    var isAppearing: Bool {
        return ld_AppearStatus == .willAppear
    }
    
    var idDisappearing: Bool {
        return ld_AppearStatus == .willDisappear
    }
    
    var isDisppeared: Bool {
        let appearStatus = ld_AppearStatus
        return appearStatus == .none || appearStatus == .didDisappear
    }
}
