//
//  TextRectangle.swift
//  text-recognition
//
//  Created by Maxim Skorynin on 14.12.2021.
//

import UIKit

import MLImage
import MLKit

final class TextFrameCalculator {
    
    func calculate(with visionText: Text, drawingLayer: CALayer, imageSize: CGSize) -> CGRect {
        let lines = visionText.blocks.flatMap { $0.lines }
        let words = lines.flatMap { $0.elements }
        
        guard let firstWord = words.first, let lastWord = words.last else {
            return .zero
        }
        
        guard let mostLenghtLine = lines.sorted(by: {
            $0.elements.last?.frame.origin.x ?? 0 > $1.elements.last?.frame.origin.x ?? 0
        }).first, let rightmostElement = mostLenghtLine.elements.last else {
            return .zero
        }

        let delta = drawingLayer.bounds.size / imageSize
        let topLeftPoint = firstWord.frame.origin * delta
        
        let bottomY = lastWord.frame.maxY * delta.height
        let rightmostX = rightmostElement.frame.maxX * delta.width
        
        let width = rightmostX - topLeftPoint.x + 20
        let height = bottomY - topLeftPoint.y + 30
        
        let origin = topLeftPoint + CGPoint(x: -10, y: -10)
        
        let size = CGSize(width: width, height: height)
        return CGRect(origin: origin, size: size)
    }
    
    func calculate(with visionText: Text) -> CGRect {
        let lines = visionText.blocks.flatMap { $0.lines }
        let words = lines.flatMap { $0.elements }
        
        guard let firstWord = words.first, let lastWord = words.last else {
            return .zero
        }
        
        guard let mostLenghtLine = lines.sorted(by: {
            $0.elements.last?.frame.origin.x ?? 0 > $1.elements.last?.frame.origin.x ?? 0
        }).first, let rightmostElement = mostLenghtLine.elements.last else {
            return .zero
        }

        let topLeftPoint = firstWord.frame.origin
        
        let bottomY = lastWord.frame.maxY
        let rightmostX = rightmostElement.frame.maxX
        
        let width = rightmostX - topLeftPoint.x + 20
        let height = bottomY - topLeftPoint.y + 30
        
        let origin = topLeftPoint + CGPoint(x: -10, y: -10)
        
        let size = CGSize(width: width, height: height)
        return CGRect(origin: origin, size: size)
    }
    
}

func * (left: CGPoint, right: CGSize) -> CGPoint {
    return CGPoint(x: left.x * right.width, y: left.y * right.height)
}

func / (left: CGSize, right: CGSize) -> CGSize {
    return CGSize(width: left.width / right.width, height: left.height / right.height)
}

func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}
