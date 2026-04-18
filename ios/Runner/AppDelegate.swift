import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let classificationChannelName = "dev.hive/classification/image_labeling"
  private let classificationModelIdentifier = "apple_vision/VNClassifyImageRequest"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: classificationChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleClassification(call: call, result: result)
    }
  }

  private func handleClassification(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "classifyImage" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String
    else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "Expected a file path for image classification.",
          details: nil
        )
      )
      return
    }

    let confidenceThreshold = (arguments["confidenceThreshold"] as? Double) ?? 0.1
    let maxLabels = (arguments["maxLabels"] as? Int) ?? 12

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let labels = try self.classifyImage(
          atPath: path,
          confidenceThreshold: Float(confidenceThreshold),
          maxLabels: maxLabels
        )

        DispatchQueue.main.async {
          result(labels)
        }
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "classification_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  private func classifyImage(
    atPath path: String,
    confidenceThreshold: Float,
    maxLabels: Int
  ) throws -> [[String: Any]] {
    let imageUrl = URL(fileURLWithPath: path)
    let request = VNClassifyImageRequest()
    let handler = VNImageRequestHandler(url: imageUrl)

    try handler.perform([request])

    let observations = (request.results as? [VNClassificationObservation] ?? [])
      .filter { $0.confidence >= confidenceThreshold }
      .sorted { $0.confidence > $1.confidence }
      .prefix(maxLabels)

    return observations.map { observation in
      [
        "label": observation.identifier,
        "confidence": Double(observation.confidence),
        "modelIdentifier": classificationModelIdentifier,
      ]
    }
  }
}
