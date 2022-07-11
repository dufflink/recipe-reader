//
//  UILabelWithPadding.swift
//  technician-cabinet-ios
//
//  Created by Maxim Skorynin on 09.12.2019.
//  Copyright © 2019 Maxim Skorynin. All rights reserved.
//

import UIKit

@IBDesignable class PaddingLabel: UILabel {

    @IBInspectable var topInset: CGFloat = 5.0
    @IBInspectable var bottomInset: CGFloat = 5.0
    
    @IBInspectable var leftInset: CGFloat = 7.0
    @IBInspectable var rightInset: CGFloat = 7.0
    
    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        } set {
            layer.cornerRadius = newValue
        }
    }
    
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return .init(width: size.width + leftInset + rightInset, height: size.height + topInset + bottomInset)
    }
    
    // MARK: - Life Cycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.masksToBounds = true
    }
    
    convenience init(topInset: CGFloat, bottomInset: CGFloat, leftInset: CGFloat, rightInset: CGFloat) {
        self.init()
        self.topInset = topInset
        self.bottomInset = bottomInset
        
        self.leftInset = leftInset
        self.rightInset = leftInset
    }

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        super.drawText(in: rect.inset(by: insets))
    }
    
}
