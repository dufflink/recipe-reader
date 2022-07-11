//
//  Storyboard.swift
//  text-recognition
//
//  Created by Maxim Skorynin on 15.12.2021.
//

import UIKit

struct Storyboard {
    
    static let main = UIStoryboard(name: "Main", bundle: nil)
    static let cameraViewController = main.instantiateViewController(withIdentifier: "CameraViewController") as? CameraViewController
    
}
