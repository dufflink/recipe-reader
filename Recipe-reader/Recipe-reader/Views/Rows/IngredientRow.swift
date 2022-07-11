//
//  IngredientRow.swift
//  text-recognition
//
//  Created by Maxim Skorynin on 13.12.2021.
//

import UIKit

final class IngredientRow: UITableViewCell {
    
    static let identifier = "IngredientRow"
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    
    @IBOutlet weak var measureLabel: PaddingLabel!
    
    func configure(from model: FormattedRecipeModel) {
        nameLabel.text = model.recipeRow.ingredient
        countLabel.text = model.recipeRow.value
        
        let measure = model.measure
        
        measureLabel.isHidden = measure.isEmpty
        measureLabel.text = measure
    }
    
}
