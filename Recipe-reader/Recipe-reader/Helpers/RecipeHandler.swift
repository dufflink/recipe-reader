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
    private let nlTagScheme: NLTagScheme = .nameType
    
    // MARK: - Life Cycle
    
    init() {
        configureTagger()
    }
    
    // MARK: - Functions
    
    func handleText(_ text: String) -> [RecipeRow] {
        var lines: [String] = []
        tagger?.string = text
        
        tagger?.enumerateTags(in: text.startIndex ..< text.endIndex, unit: .sentence, scheme: nlTagScheme) { _, tokenRange in
            let line = String(text[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append(line)
            
            return true
        }
        
        return tagRecipeElements(lines)
    }
    
    func handleMLKitText(_ text: Text) -> [RecipeRow] {
        let lines = text.blocks.flatMap { $0.lines }.map { $0.text }
        return tagRecipeElements(lines)
    }
    
    private func tagRecipeElements(_ lines: [String]) -> [RecipeRow] {
        return lines.map { line in
            tagger?.string = line.lowercased()
            let currentRecipeRow = RecipeRow()
            
            tagger?.enumerateTags(in: line.startIndex ..< line.endIndex, unit: .word, scheme: nlTagScheme, options: [.omitWhitespace]) { tag, tokenRange in
                guard let tag = tag, let type = WordType(rawValue: tag.rawValue) else {
                    return false
                }
                
                let value = String(line[tokenRange])
                
                switch type {
                    case .value:
                        currentRecipeRow.value += value
                    case .measure:
                        currentRecipeRow.measure += " \(value)"
                    case .ingredient:
                        currentRecipeRow.ingredient += " \(value)"
                    case .combination:
                        currentRecipeRow.combination += value
                }

                return true
            }
            
            if let (value, measure) = split(currentRecipeRow.combination) {
                currentRecipeRow.value = value
                currentRecipeRow.measure = measure
            }
            
            return currentRecipeRow
        }
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
        
        let tagger = NLTagger(tagSchemes: [nlTagScheme])
        tagger.setModels([nlModel], forTagScheme: nlTagScheme)
        
        self.tagger = tagger
    }
    
}
