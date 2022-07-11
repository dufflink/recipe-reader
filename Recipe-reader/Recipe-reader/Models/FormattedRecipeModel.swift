//
//  FormattedRecipeModel.swift
//  text-recognition
//
//  Created by Maxim Skorynin on 15.12.2021.
//

import UIKit

final class FormattedRecipeModel {
    
    var recipeRow: RecipeRow
    
    // MARK: - Life Cycle
    
    init(recipeRow: RecipeRow) {
        self.recipeRow = recipeRow
    }
    
    // MARK: - Properites
    
    var ingredient: NSAttributedString {
        let attributedString = NSMutableAttributedString(string: recipeRow.ingredient)
        let ingredientRange = NSRange(location: 0, length: recipeRow.ingredient.count)
        
        attributedString.addAttributes([
            .foregroundColor: UIColor.lightGray
        ], range: ingredientRange)
        
        if !recipeRow.measure.isEmpty {
            let measure = ", \(recipeRow.measure.lowercased())"
            let str = NSAttributedString(string: measure)
            
            attributedString.append(str)
            
            let measureRange = NSRange(location: ingredientRange.length + 2, length: recipeRow.measure.count)
            
            attributedString.addAttributes([
                .foregroundColor: UIColor.systemPurple
            ], range: measureRange)
        }
        
        return attributedString
    }
    
    var measure: String {
        return recipeRow.measure.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
}
