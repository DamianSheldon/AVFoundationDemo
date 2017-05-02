//
//  UIViewController+DMLAdditions.swift
//  AVFoundationDemo
//
//  Created by DongMeiliang on 15/12/2016.
//  Copyright © 2016 Meiliang Dong. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    open func presentAlert(title: String, message: String) -> Void {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        present(alert, animated: true, completion: nil)
    }
}
