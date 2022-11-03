//
//  CameraViewController.swift
//  text-recognition
//
//  Created by Maxim Skorynin on 15.12.2021.
//

import AVKit
import UIKit

import MLKit
import CropViewController

final class CameraViewController: UIViewController {
    
    weak var recipeHandlerDelegate: RecipeHandlerDelegate?
    
    @IBOutlet private weak var videoFrame: UIView!
    
    private let recipeHandler = RecipeHandler()
    private let textFrameCalculator = TextFrameCalculator()
    
    private var captureSession: AVCaptureSession?
    private var photoOutput = AVCapturePhotoOutput()
    
    private lazy var textRecognizer: TextRecognizer = {
        let options = TextRecognizerOptions()
        return TextRecognizer.textRecognizer(options: options)
    }()
    
    private var textFrame: CGRect = .zero
    private var drawingLayer: DrawingLayer!
    
    private var queue = OperationQueue()
    
    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCaptureSession()
        configureDrawingLayer()
        
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.startRunning()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession?.stopRunning()
    }
    
    
    // MARK: - Functions
    
    @IBAction func takePhotoDidPress(_ sender: Any) {
        capturePhoto()
    }
    
    private func configureDrawingLayer() {
        drawingLayer = DrawingLayer()
        drawingLayer?.frame = videoFrame.bounds
        
        videoFrame.layer.addSublayer(drawingLayer)
    }
    
    private func configureCaptureSession() {
        let session = AVCaptureSession()
        
        session.beginConfiguration()
        session.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("Couldn't create video input")
            return
        }
        
        session.addInput(input)
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resize
        
        videoFrame.layer.insertSublayer(preview, at: 0)
        preview.frame = videoFrame.bounds
        
        let queue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        let videoOutput = AVCaptureVideoDataOutput()
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        
        let settings: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
        ]
        
        videoOutput.videoSettings = settings
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            
            videoOutput.connection(with: .video)?.videoOrientation = .portrait
            session.commitConfiguration()
            
            captureSession = session
        } else {
            print("Couldn't add video output")
        }
    }
    
    private func detectTextFrame(sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let visionImage = VisionImage(buffer: sampleBuffer)
        
        queue.addOperation { [weak self] in
            self?.textRecognizer.process(visionImage) { (visionText, error) in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                
                guard let visionText = visionText else {
                    return
                }
                
                var textDrawingRectangle: CGRect = .zero
                
                if let drawingLayer = self?.drawingLayer {
                    self?.textFrame = self?.textFrameCalculator.calculate(with: visionText) ?? .zero
                    textDrawingRectangle = self?.textFrameCalculator.calculate(with: visionText, drawingLayer: drawingLayer, imageSize: ciImage.extent.size) ?? .zero
                }
                
                DispatchQueue.main.async {
                    self?.drawingLayer?.draw(with: textDrawingRectangle)
                }
            }
        }
    }
    
    private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        
        guard let photoPreviewType = settings.availablePreviewPhotoPixelFormatTypes.first else {
            return
        }
        
        settings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func readText(in image: UIImage) {
        let visionImage = VisionImage(image: image)
        
        queue.addOperation { [weak self] in
            self?.textRecognizer.process(visionImage) { (visionText, error) in
                if let error = error {
                    print(error.localizedDescription)
                    return
                }
                
                guard let visionText = visionText else {
                    return
                }
                
                let recipeRows = self?.recipeHandler.handleMLKitText(visionText) ?? []
                self?.recipeHandlerDelegate?.recipeDidHandle(recipeRows: recipeRows)
            }
        }
    }
    
}

// MARK: - Video Delegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        detectTextFrame(sampleBuffer: sampleBuffer)
    }
    
}

// MARK: - Photo Delegate

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(), let image = UIImage(data: imageData) else {
            if let error = error {
                print(error.localizedDescription)
            }
            
            return
        }
        
        let cropViewController = CropViewController(image: image)
        
        cropViewController.delegate = self
        cropViewController.imageCropFrame = textFrame
        
        present(cropViewController, animated: true)
    }
    
}

// MARK: - Crop View Controller Delegate

extension CameraViewController: CropViewControllerDelegate {
    
    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        readText(in: image)

        cropViewController.dismiss(animated: false) {
            self.dismiss(animated: true)
        }
    }
    
    func cropViewController(_ cropViewController: CropViewController, didFinishCancelled cancelled: Bool) {
        cropViewController.dismiss(animated: false)
    }
    
}
