//
//  RecipeHandler.swift
//  text-recognition
//
//  Created by Maxim Skorynin on 14.12.2021.
//

import CoreML
import NaturalLanguage

import MLKit

final class RecipeHandler {
    
    private var tagger: NLTagger?
    private let nlTagScheme = NLTagScheme("Recipe")
    
    // MARK: - Life Cycle
    
    init() {
        configureTagger()
    }
    
    // MARK: - Functions
    
    func handleText(_ text: String) -> [RecipeRow] {
        var lines: [String] = []
        self.tagger?.string = text
        
        self.tagger?.enumerateTags(in: text.startIndex ..< text.endIndex, unit: .sentence, scheme: self.nlTagScheme, options: []) { _, tokenRange in
            let line = String(text[tokenRange])
            lines.append(line)
            
            return true
        }
        
        return tagRecipeLines(lines)
    }
    
    func handleMLKitText(_ visionText: Text) -> [RecipeRow] {
        let lines = visionText.blocks.flatMap { $0.lines }.map { $0.text }
        return tagRecipeLines(lines)
    }
    
    private func tagRecipeLines(_ lines: [String]) -> [RecipeRow] {
        var recipeRows: [RecipeRow] = []
        
        lines.forEach { line in
            self.tagger?.string = line.lowercased()

            var previousType: WordType = .value
            let currentRecipeRow = RecipeRow()
            
            self.tagger?.enumerateTags(in: line.startIndex ..< line.endIndex, unit: .word, scheme: self.nlTagScheme, options: [.omitWhitespace]) { tag, tokenRange in
                guard let tag = tag, let type = WordType(rawValue: tag.rawValue) else {
                    return false
                }
                
                let value = String(line[tokenRange])
                
                switch type {
                    case .value:
                        if previousType == .value {
                            currentRecipeRow.value += value
                        }
                    case .measure:
                        currentRecipeRow.measure += value
                    case .ingredient:
                        currentRecipeRow.ingredient += " \(value)"
                    case .whitespace:
                        switch previousType {
                            case .value, .combination, .whitespace:
                                break
                            case .measure:
                                currentRecipeRow.measure += value
                            case .ingredient:
                                currentRecipeRow.ingredient += value
                        }
                    case .combination:
                        currentRecipeRow.combination += value
                }
                
                if type != .whitespace {
                    previousType = type
                }
                
                return true
            }
            
            if let (value, measure) = split(currentRecipeRow.combination) {
                currentRecipeRow.value = value
                currentRecipeRow.measure = measure
            }
            
            recipeRows += [currentRecipeRow]
        }
        
        return recipeRows
    }
    
    private func split(_ combination: String) -> (value: String, measure: String)? {
        guard !combination.isEmpty else {
            return nil
        }
        
        var valueEndIndex = -1
        var metNotNumber = false

        for item in combination {
            let string = String(item)
            
            if Int(string) == nil {
                if metNotNumber {
                    break
                }

                metNotNumber = true
            } else {
                metNotNumber = false
            }
            
            valueEndIndex += 1
        }
        
        let wordStartIndex = combination.index(combination.startIndex, offsetBy: valueEndIndex)
        
        let value = String(combination[combination.startIndex ..< wordStartIndex])
        let measure = String(combination[wordStartIndex ..< combination.endIndex])
        
        return (value: value, measure: measure)
    }
    
    private func configureTagger() {
        let configuration = MLModelConfiguration()
        
        guard let model = try? RecipeWordTaggerModel(configuration: configuration).model else {
            print("Couldn't init RecipeWordTagger model")
            return
        }

        guard let nlModel = try? NLModel(mlModel: model) else {
            return
        }
        
        let tagger = NLTagger(tagSchemes: [.nameType, nlTagScheme])
        tagger.setModels([nlModel], forTagScheme: nlTagScheme)
        
        self.tagger = tagger
    }
    
}
