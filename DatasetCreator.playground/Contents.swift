import Foundation
import PlaygroundSupport

// MARK: - Prepared values

/// Sentence element types
enum Label: String, Encodable {
    
    case value
    case measure
    
    case ingredient
    case combination
    
}

/// Sentence element
struct WordObject: Hashable {
    
    var token: String
    var label: Label
    
}

/// Sentence
class SentenceObject: Encodable {
    
    var tokens: [String] = []
    var labels: [Label] = []
    
}

/// Final JSON
struct FinalJSON: Encodable {
    
    var objects: [SentenceObject]
    
}

// MARK: - JSON Data preparing

/// Loading of the "IngredientListJsonObjects.json" from the "Resource" folder.
/// Don't forget to add this file to the "Resource" folder before

func loadJSONList() -> Data? {
    guard let jsonURL = Bundle.main.url(forResource: "IngredientDataSet", withExtension: "json") else {
        print("JSON file is not found")
        return nil
    }
    
    return try? Data(contentsOf: jsonURL, options: .alwaysMapped)
}

/// Parsing of uniqe ingredient names from JSON

func getIngredients() -> [WordObject] {
    let decoder = JSONDecoder()
    
    guard let jsonData = loadJSONList(), let jsonArray = try? decoder.decode([IngredientArray].self, from: jsonData) else {
        return []
    }
    
    return Set(jsonArray.flatMap { $0.ingredients }).map {
        return WordObject(token: $0, label: .ingredient)
    }
}

/// Values preparing

func getValues() -> [WordObject] {
    var values: [String] = [
        "1/2", "1/3", "1/4", "1/5", "2/3", "3/4",
        "0,25", "0.25", "0,5", "1,5", "0.5", "1.5", "2.5", "2,5",
        "1", "2", "3", "4", "5", "6", "7", "8", "9"
    ]
    
    values += values.flatMap { Array(repeating: $0, count: 2) }
    values += (10 ... 1000).filter { $0 % 25 == 0 }.map { String($0) }
    
    return values.map { WordObject(token: $0, label: .value) }.shuffled()
}

/// Measures preparing

func getMeasures() -> [WordObject] {
    var measures = ["tbsp", "tbsp.", "tablespoon", "tablespoons", "tb.", "tb", "tbl.", "tbl", "tsp", "tsp.", "teaspoon", "teaspoons", "oz", "oz.", "ounce", "ounces", "c", "c.", "cup", "cups", "qt", "qt.", "quart", "pt", "pt.", "pint", "pints", "ml", "milliliter", "milliliters", "g", "gram", "grams", "kg", "kilogram", "kilograms", "l", "liter", "liters", "pinch", "pinches", "gal", "gal.", "gallons", "lb.", "lb", "pkg.", "pkg", "package", "packages","can", "cans", "box", "boxes", "stick", "sticks", "bag", "bags"]
    
    measures += ["fluid ounce", "fluid ounces", "fl. oz"].flatMap { Array(repeating: $0, count: 10) }
    return measures.map { WordObject(token: $0, label: .measure) }.shuffled()
}

struct IngredientArray: Decodable {
    let ingredients: [String]
}

/// Save a final JSON file

func save(_ data: Data, fileName: String) {
    guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .json5Allowed) else {
        print("Couldn't create json object")
        return
    }
    
    guard let newData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted), let string = String(data: newData, encoding: .utf8)?.replacingOccurrences(of: "\\", with: "") else {
        return
    }
    
    let fileManager = FileManager()
    let url = playgroundSharedDataDirectory.appendingPathComponent("\(fileName).json")
    
    do {
        try fileManager.createDirectory(at: playgroundSharedDataDirectory, withIntermediateDirectories: true, attributes: [:])
        try string.write(to: url, atomically: true, encoding: .utf8)
        
        print("New JSON file was saved here: \(url)")
    } catch {
        print(error)
    }
}

/// Sentences generation
///
/// Here we create different types of sentences for each ingredient type

func generateSentences(ingredients: [WordObject], measures: [WordObject], values: [WordObject]) -> Set<[WordObject]> {
    var measureIndex = 0
    var valueIndex = 0

    var isFirstWay = true
    
    return ingredients.reduce(into: Set<[WordObject]>()) { sentences, ingredient in
        if measureIndex == measures.count {
            measureIndex = 0
        }

        if valueIndex == values.count {
            valueIndex = 0
        }

        let measure = measures[measureIndex]
        let value = values[valueIndex]

        measureIndex += 1
        valueIndex += 1

        let token = value.token + measure.token
        let combination = WordObject(token: token, label: .combination)
        
        if isFirstWay {
            sentences.insert([value, ingredient]) // 10 sugar
            sentences.insert([combination, ingredient]) // 10tbsp sugar
        } else {
            sentences.insert([ingredient]) // sugar
        }
        
        sentences.insert([value, measure, ingredient]) // 10 tbsp sugar
        isFirstWay.toggle()
    }
}

/// Collocation separation
///
/// Here we should handle a case if an ingredient name or a measure consists few words
///
/// Example:
/// "cold black tea" -> ["cold", "black", "tea"] where each word has the "ingredient" label
/// "fl. oz" -> ["fl.", "oz"] where each word has the "measure" label

func separateCollocations(in senteces: Set<[WordObject]>) -> [SentenceObject] {
    return sentences.compactMap { sentence in
        let sentenceObject = SentenceObject()

        sentence.map { word in
            word.token.split(separator: " ").map { part in
                let newToken = String(part)

                sentenceObject.tokens.append(newToken)
                sentenceObject.labels.append(word.label)
            }
        }
        
        return sentenceObject
    }
}

// MARK: - Programm

var values = getValues()
var measures = getMeasures()
var ingredients = getIngredients()

print("Ingredient: \(ingredients.count)")
print("Values: \(values.count)")
print("Measures: \(measures.count)")

let sentences = generateSentences(ingredients: ingredients, measures: measures, values: values)
let preparedSentences = separateCollocations(in: sentences)

/// Encode and save a final JSON

let json = FinalJSON(objects: preparedSentences)
let data = try JSONEncoder().encode(json.objects)

save(data, fileName: "exp10-test")

/// [Run] Launch this programm here

