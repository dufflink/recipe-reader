//
//  LiveTextHandler.swift
//  text-recognition
//
//  Created by Maxim Skorynin on 15.12.2021.
//

import UIKit

final class LiveTextHandlerView: UIView, UIKeyInput {

    weak var recipeHandlerDelegate: RecipeHandlerDelegate?
    
    private let recipeHandler = RecipeHandler()
    
    var hasText = true
    
    // MARK: - UIKey Input Functions

    func insertText(_ text: String) {
        let recipeRows = recipeHandler.handleText(text)
        
        if !recipeRows.isEmpty {
            recipeHandlerDelegate?.recipeDidHandle(recipeRows: recipeRows)
        }
    }

    func deleteBackward() { }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
}
