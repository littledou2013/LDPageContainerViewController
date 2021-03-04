//
//  LDPageContainerViewControllerPrefetching.swift
//  LDPageContainerViewController
//
//  Created by littledou on 2021/2/23.
//

import UIKit

protocol LDPageContainerViewControllerPrefetching: class {
    func containerViewController(_ containerViewController: LDPageContainerViewController, prefetchIndexes indexes: Set<Int>, cancelPrefechIndexes cancelIndexes: Set<Int>)
}

extension LDPageContainerViewControllerPrefetching {
    func containerViewController(_ containerViewController: LDPageContainerViewController, prefetchIndexes indexs: Set<Int>, cancelPrefechIndexes: Set<Int>) {
        
    }
}
