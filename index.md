# Recipe Reader Part #2

Throughout [the first part](https://evilmartians.com/chronicles/realtime-text-analysis-word-tagger-pro-computer-vision-part-1) of the article series,
we uncovered the data requirements for creating a Word Tagger model and where to find that data. We learned about the intricacies and edge cases
involved in our task of recognizing culinary recipes. After that, we wrote a script that generate a dataset, and then we trained the model.

Now it’s time for the most delicious part of the process! Next, we’ll create an iOS application from scratch, and learn about the 
[GoogleMLKit/TextRecognition](https://developers.google.com/ml-kit/vision/text-recognition/ios) (iOS 13.0) and native [Live Text](https://support.apple.com/en-us/HT212630) (iOS 15.0) tools that allow us to recognize text from a video stream or an image using 
the iPhone camera. We’ll also apply our Word Tagger model to convert the text of an English-language text of recipe.

## Preparations
Let's start by creating a new iOS project in Xcode. We’ll set the minimum supported version of iOS as 13.0. Add the GoogleMLKit/TextRecognition 
dependency to the project using Cocoapods and import the Word Tagger model (generated in the previous part) into the root folder of the project.

During the first stage, our task will be to recognize printed text using a mobile device's camera. Also, as in the previous chapter, 
I won’t discuss each development stage in too much detail, but will instead try to hone in  only on those moments that may be fascinating for you.
In any case, the final code of the project can be found in the repository: [Recipe Reader](https://github.com/dufflink/recipe-reader/tree/master).

## Live Text
One of the easiest and most effective ways to recognize data using a camera is Live Text. This technology can recognize text, links, 
phone numbers, and QR codes. Apple released this feature in iOS 15.0. This option is not suitable for those who want to support iOS versions <15.0. 
But nevertheless, this is a very fantastic tool, which, by the way, is also available in SwiftUI.

Let's start by implementing a handler class that will be responsible for receiving text using LiveText: [LiveTextHandlerView](https://github.com/dufflink/recipe-reader/blob/a455943966888cf09ec7fe85b2149801e0562812/Recipe-reader/Recipe-reader/Views/LiveTextHandlerView.swift#L10). 
Live Text implementation is rather odd because we need to use the `UIKeyInput` class. Moreover, `UIKeyInput` inherits from `NSObjectProtocol`, 
so the easiest way is to inherit `UIView` from `UIKeyInput`. Thus, it requires describing two methods and one property:

```swift
final class LiveTextHandlerView: UIView, UIKeyInput {

    var hasText = true
    
    // MARK: - UIKey Input Functions

    func insertText(_ text: String) { }

    func deleteBackward() { }
    
}

```

`insertText(_ text: String)` is exactly the method where we’ll receive the Live Text work result. Leave the other two as in the image above, 
because in our case we won’t need them. One of the possibilities to launch Live Text is `UIButton` with a special `UIAction`. 
This may work for other UI elements that use `UIAction`, such as `UIMenu` or `UITextField`. Notice the [addLiveTextButton()](https://github.com/dufflink/recipe-reader/blob/a455943966888cf09ec7fe85b2149801e0562812/Recipe-reader/Recipe-reader/Controllers/RecipeViewController.swift#L67) 
method:

```swift
private func addLiveTextButton() {
        if #available(iOS 15.0, *) {
            liveTextHandlerView.recipeHandlerDelegate = self
            let liveTextCameraAction = UIAction.captureTextFromCamera(responder: liveTextHandlerView, identifier: nil)
            
            let button = RRButton(primaryAction: liveTextCameraAction)
            
            button.setTitle("Live Text", for: .normal)
            button.setImage(nil, for: .normal)
            
            buttonsStackView.insertArrangedSubview(button, at: 0)
        }
    }
```
[UIAction.captureTextFromCamera](https://developer.apple.com/documentation/uikit/uiaction/3778552-capturetextfromcamera?changes=___2): this 
`UIAction` is responsible for calling the function we need. It requires a `responder` object as a parameter, which will be the object of our 
`LiveTextHandlerView` class.

{% sidenote %}
I strongly recommend placing the `liveTextHandlerView` element directly on the screen view in any convenient way (view.addSubview or via XIB). 
Otherwise, the Live Text screen UI may not work properly.

Try launching your code and scanning any text. Check the output of the `insertText(_ text: String)` method to make sure the basic Live Text 
implementation was successful.

## GoogleMLKit/TextRecognition
Now let's move on to building the feature that will use the device's regular camera and GoogleMLKit/TextRecognition. 
You can find the entire code in the [CameraViewController](https://github.com/dufflink/recipe-reader/blob/a455943966888cf09ec7fe85b2149801e0562812/Recipe-reader/Recipe-reader/Controllers/CameraViewController.swift#L14) class.

First, we need to set up the `captureSession: AVCaptureSession` to capture video and the `photoSession: AVCapturePhotoOutput` to create a photo. 
You can find the main configuration in the [configureCaptureSession()](https://github.com/dufflink/recipe-reader/blob/a455943966888cf09ec7fe85b2149801e0562812/Recipe-reader/Recipe-reader/Controllers/CameraViewController.swift#L73) function:

```swift
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
    } else {
        print("Couldn't add photo output")
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
```

To improve the user experience, I thought it would be great to display a colored frame around the text when it's been recognized. 
This feature implementation uses the [TextRecognizer](https://developers.google.com/ml-kit/reference/swift/mlkittextrecognition/api/reference/Classes/TextRecognizer) class from the MLKit (Google) framework, which will later be responsible for the recognition 
of the text itself. It works like this:

1. We must override the `captureSession delegate`, and pass the results of its work (data from the camera) to the [detectTextFrame()](https://github.com/dufflink/recipe-reader/blob/a455943966888cf09ec7fe85b2149801e0562812/Recipe-reader/Recipe-reader/Controllers/CameraViewController.swift#L121)
method

```swift
// MARK: - Video Delegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        detectTextFrame(sampleBuffer: sampleBuffer)
    }
    
}
```
2. Inside the `detectTextFrame()` function, video data of the `CMSampleBuffer` type is converted into the [VisionImage](https://developers.google.com/ml-kit/reference/swift/mlkitvision/api/reference/Classes/VisionImage) object, which is passed to 
the `textRecognizer` for recognition.

3. After a successful operation, the `textRecognizer` generates the [Text](https://developers.google.com/ml-kit/reference/swift/mlkittextrecognition/api/reference/Classes/Text) object.

```swift
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
```

4. At this stage, the [TextFrameCalculator](https://github.com/dufflink/recipe-reader/blob/master/Recipe-reader/Recipe-reader/Helpers/TextFrameCalculator.swift) class, 
which I wrote specifically for this task, takes over; it creates a `CGRect` instance based on the Text object. Let's analyze the example in the 
image below to better understand the algorithm:

❗️[image] - text-frame-calculator.png

The frame coordinates and size are created based on three points on the (x,y) axis:
(A) The first word on the first line
(B) The last word in the longest line
(C) The last line

All this is possible due to the fact that MLKit's `TextRecognizer` allows you to find the coordinates of each word in a recognized text. 
The [DrawingLayer](https://github.com/dufflink/recipe-reader/blob/master/Recipe-reader/Recipe-reader/Views/DrawingLayer.swift) class is 
directly responsible for drawing the colored frame itself, which uses the `CGRect` instance.

❗️[Video] - colored-frame.mp4

Another optional, but very successful addition (<-- ❗️ there is comment in the Google doc) is the CropViewController. 
This allows you to adjust the area of the text in a photo and smooth out the shortcomings of the colored frame drawing method. 
This solution is based on an open-source dependency: [CropViewController](https://github.com/TimOliver/TOCropViewController).

After the `Take a photo` button is clicked, the [capturePhoto()] method is called. 
This method captures data from the camera and converts it into the `AVCapturePhoto` object.

```swift
private func capturePhoto() {
    let settings = AVCapturePhotoSettings()

    guard let photoPreviewType = settings.availablePreviewPhotoPixelFormatTypes.first else {
        return
    }

    settings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]
    photoOutput.capturePhoto(with: settings, delegate: self)
}
```

We get this result with the photo in the `AVCapturePhotoCaptureDelegate` method:
[photoOutput(_ output: didFinishProcessingPhoto:)](https://github.com/dufflink/recipe-reader/blob/a455943966888cf09ec7fe85b2149801e0562812/Recipe-reader/Recipe-reader/Controllers/CameraViewController.swift#L201); 
convert it to `UIImage` and then pass it to the `cropViewController`.

```swift
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
```

{% sidenote %}
`CropViewController` has an `imageCropFrame` property that can be defined during the initialization of this screen. 
We calculated the `textFrame` variable value in the previous step when we were drawing the colored frame.

❗️[Video] - crop-view-controller.mp4 

We get the edited result in the `CropViewControllerDelegate` method and pass it further to the function: [readText(in image: UIImage)](https://github.com/dufflink/recipe-reader/blob/a455943966888cf09ec7fe85b2149801e0562812/Recipe-reader/Recipe-reader/Controllers/CameraViewController.swift#L165)

```swift
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
```

Here, the `textRecognizer` again takes over, but with the goal of simply getting the text from the image. 
Check the result of the entire flow to make sure that text recognition using Google MILKit works correctly.

```swift
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
```

## Recipe handler
The most fascinating part of this process is applying the WordTagger model to the text obtained in the previous step. 
Let's start with the [RecipeHandler](https://github.com/dufflink/recipe-reader/blob/a455943966888cf09ec7fe85b2149801e0562812/Recipe-reader/Recipe-reader/Helpers/RecipeHandler.swift#L13) class configuration.

```swift
import CoreML
import NaturalLanguage

final class RecipeHandler {
    
    private var tagger: NLTagger?
    private let nlTagScheme: NLTagScheme = .tokenType
    
    // MARK: - Life Cycle
    
    init() {
        configureTagger()
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
```

First, we need to import two frameworks: [CoreML](https://developer.apple.com/documentation/coreml) and [NaturalLanguage](https://developer.apple.com/documentation/naturallanguage/). 
The first one will allow us to use our WordTagger model. The second will provide a tool for working with text: [NLTagger](https://developer.apple.com/documentation/naturallanguage/nltagger).

The `NLTagger` object is a key component that will perform two functions:
1. Break solid objects of type `String` into an array of strings, if necessary (for example, for Live Text)

{% sidenote %}
As you recall, breaking the text into separate lines is very important in our example, because we want to recognize cooking recipes where 
each ingredient is written on a new line.

2. Parse each individual line and find keywords in it with corresponding tags (value, measure, ingredient, or combination)

As a result of the Live Text work, we get a `String` object. Therefore, the first step is splitting it into an array of strings `[String]`.
Let's take a look at the [handleText(_ text: String)](https://github.com/dufflink/recipe-reader/blob/a455943966888cf09ec7fe85b2149801e0562812/Recipe-reader/Recipe-reader/Helpers/RecipeHandler.swift#L26) method code:

```swift
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
```

Here we call the `enumerateTags()` method of the `NLTagger` object, which asks us to provide a few parameters:
- `range`: the area of the text where the analysis is carried out. In our case, we must specify the range from the beginning of the string to its end.
- `unit`: The linguistic unit of scale you’re interested in, such as `.word`, `.sentence`, `.paragraph`, or `.document`. I experimented with the 
`.sentence` and the `.paragraph` values. Both cases had the same result because, in fact, each line in the recipe is both a separate paragraph and a sentence.

- `scheme`: The [NLTagScheme](https://developer.apple.com/documentation/naturallanguage/nltagscheme) the tagger uses to tag the string, 
such as `.lexicalClass`, `.nameType`, `.tokenType`, `.lemma`, `.language`, `.script`, etc. When initializing a linguistic tagger, 
you can specify one or more tag schemes that correspond to the kind of information you’re interested in for a selection of natural language text. 
The returned tag value depends on the specified scheme. For example, given the token “Überraschung”, the returned tag is [noun](https://developer.apple.com/documentation/naturallanguage/nltag/2976591-noun) when using the 
[lexicalClass](https://developer.apple.com/documentation/naturallanguage/nltagscheme/2976610-lexicalclass) tag scheme, [german](https://developer.apple.com/documentation/naturallanguage/nllanguage/2976531-german) (German language) when 
using the [language](https://developer.apple.com/documentation/naturallanguage/nltagscheme/2976608-language) tag scheme, and “Latn” (Latin script) 
when using the [script](https://developer.apple.com/documentation/naturallanguage/nltagscheme/2976613-script) tag scheme, as shown in the following code.

In fact, when choosing the `scheme` type we need, everything is quite simple and only two options are logically suitable: `.nameType` and `.tokenType`. 
I experimented with both of them and didn't notice any difference. 

{% sidenote %}
❗️Note the `NLTagScheme` value must be identical both when initializing the `NLTagger` object and when we use the `enumerateTags()` method. 

As a result, we get the string array `lines` and pass them further to the `tagRecipeElements(_ lines: [String])` method, which we’ll talk about a bit later.

In the case of MLKit (Google) everything is easier. The result of its work is the `Text` object which already contains the `blocks: [TextBlock]` property. 
Using this property we can get the string array without any extra effort:

```swift
func handleMLKitText(_ text: Text) -> [RecipeRow] {
    let lines = text.blocks.flatMap { $0.lines }.map { $0.text }
    return tagRecipeElements(lines)
}
```

You’ve probably already noticed that all roads lead us to the last stage: parsing the words in each line from the string array using the 
[tagRecipeElements(_ lines: [String])](https://github.com/dufflink/recipe-reader/blob/a455943966888cf09ec7fe85b2149801e0562812/Recipe-reader/Recipe-reader/Helpers/RecipeHandler.swift#L45) method:

```swift
private func tagRecipeElements(_ lines: [String]) -> [RecipeRow] {
    return lines.map { line in
        tagger?.string = line.lowercased()
        let currentRecipeRow = RecipeRow()

        tagger?.enumerateTags(in: line.startIndex ..< line.endIndex, unit: .word, scheme: nlTagScheme, options: [.omitWhitespace]) { tag, tokenRange in
            guard let tag = tag, let tagType = TagType(rawValue: tag.rawValue) else {
                return false
            }

            let value = String(line[tokenRange])

            switch tagType {
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
```

The algorithm is quite simple. In the beginning, we go through each line in the string array and apply the `enumerateTags()` method of the 
`NLTagger` object with the necessary parameters to each of the lines:

- `range`: from the beginning to the end of the line
- `unit`: `.word`, since we need every word in the line
- `scheme`: use the previously created `NLTagScheme` variable (`.nameType`)
- `options`: In this case, we use the `.omitWhitescapse` option, which allows you to split a line of text exactly by whitecaps,
omitting them during analysis. You can read about other possible options in the documentation from Apple: [NLTagger.Options](https://developer.apple.com/documentation/naturallanguage/nltagger/options).

The result of the `enumerateTags()` method is a pair of variables for each found word:
- `tag: NLTag?`: one of the label values from our `WordTagger` model (value, measure, ingredient, or combination).
- `tokenRange: Range<String.Index>`: the text area that contains the word with the corresponding tag.

❗️[Image] - enumerate-tags.png

Using the `tokenRange` variable, we can get the text value of a needed word from the current line:
```swift
let value = String(line[tokenRange])
```

And using the `tag` variable, we will store this value in the `RecipeRow` object, which is created separately for each line 
and has the corresponding properties: value, measure, ingredient, and combination.

```swift
switch tagType {
    case .value:
        currentRecipeRow.value += value
    case .measure:
        currentRecipeRow.measure += " \(value)"

    case .ingredient:
        currentRecipeRow.ingredient += " \(value)"
    case .combination:
        currentRecipeRow.combination += value
}
```

To handle cases when a `value` and a `measure` can be glued together (we call this a combination), 
the special [split(_ combination: String)](https://github.com/dufflink/recipe-reader/blob/50f3a2ddaa8d7e61f6c9793dc4e152228ce6ad1d/Recipe-reader/Recipe-reader/Helpers/RecipeHandler.swift#L81)
method is used:

```swift
private func split(_ combination: String) -> (value: String, measure: String)? {
    guard !combination.isEmpty else {
        return nil
    }

    var valueEndIndex = -1
    var didMetSymbol = false

    for item in combination {
        let string = String(item)

        if Int(string) == nil {
            if didMetSymbol {
                break
            }

            didMetSymbol = true
        } else {
            didMetSymbol = false
        }

        valueEndIndex += 1
    }

    let wordStartIndex = combination.index(combination.startIndex, offsetBy: valueEndIndex)

    let value = String(combination[combination.startIndex ..< wordStartIndex])
    let measure = String(combination[wordStartIndex ..< combination.endIndex])

    return (value: value, measure: measure)
}
```

The `RecipeRow` object array is the result that should be at the end of the article series about the WordTagger model. 
Now, you use this data to display it in the UI interface:

❗️[Video] - final-demo-app.mp4

Conclusion


