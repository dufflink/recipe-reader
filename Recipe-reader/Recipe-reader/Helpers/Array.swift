//
//  Array.swift
//  text-recognition
//
//  Created by Maxim Skorynin on 13.12.2021.
//

extension Array {
    
    public subscript(safe index: Int) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }

        return self[index]
    }
    
}
