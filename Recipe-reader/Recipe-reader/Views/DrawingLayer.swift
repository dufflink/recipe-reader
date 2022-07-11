//
//  DrawingLayer.swift
//  text-recognition
//
//  Created by Maxim Skorynin on 14.12.2021.
//

import UIKit

final class DrawingLayer: CALayer {
    
    private var boundingBox: CALayer!
    
    // MARK: - Life Cycle
    
    override init() {
        super.init()
        boundingBox = CALayer()
        
        boundingBox.frame = .zero
        boundingBox.borderWidth = 3
        
        let color = #colorLiteral(red: 0.3921568627, green: 0.4509803922, blue: 1, alpha: 1)
        
        boundingBox.borderColor = color.withAlphaComponent(0.6).cgColor
        boundingBox.backgroundColor = color.withAlphaComponent(0.1).cgColor
        
        boundingBox.cornerRadius = 10
        addSublayer(boundingBox)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        print("init(coder:) has not been implemented")
    }
    
    // MARK: - Functions
    
    func draw(with rect: CGRect) {
        boundingBox.frame = rect
        boundingBox.setNeedsLayout()
    }
    
}
