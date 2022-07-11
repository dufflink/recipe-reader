//
//  RRButton.swift
//  Recipe-reader
//
//  Created by Maxim Skorynin on 16.12.2021.
//

import UIKit

final class RRButton: UIButton {
    
    // MARK: - Life Cycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        configure()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    // MARK: - Functions
    
    private func configure() {
        setTitleColor(UIColor.white, for: .normal)
        backgroundColor = #colorLiteral(red: 0.3921568627, green: 0.4509803922, blue: 1, alpha: 1)
        
        layer.cornerRadius = 10
    }
    
}
