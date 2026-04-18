import Flutter
import ImageIO
import Photos
import UIKit
import UniformTypeIdentifiers
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let classificationChannelName = "dev.hive/classification/image_labeling"
  private let classificationModelIdentifier = "apple_vision/VNClassifyImageRequest"
  private let visionMaxDimension = 1600

  private var classificationChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    ensureClassificationChannelConfigured()

    return didFinish
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    ensureClassificationChannelConfigured()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureClassificationChannel(binaryMessenger: engineBridge.applicationRegistrar.messenger())
  }

  private func configureClassificationChannel(binaryMessenger: FlutterBinaryMessenger) {
    guard classificationChannel == nil else {
      return
    }

    let channel = FlutterMethodChannel(
      name: classificationChannelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleClassification(call: call, result: result)
    }
    classificationChannel = channel
  }

  private func ensureClassificationChannelConfigured() {
    if classificationChannel != nil {
      return
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      configureClassificationChannel(binaryMessenger: controller.binaryMessenger)
    }
  }

  private func handleClassification(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "classifyAsset" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard let arguments = call.arguments as? [String: Any],
      let assetId = arguments["assetId"] as? String,
      !assetId.isEmpty
    else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "Expected an asset identifier for image classification.",
          details: nil
        )
      )
      return
    }

    let fallbackPath = arguments["fallbackPath"] as? String
    let confidenceThreshold = (arguments["confidenceThreshold"] as? Double) ?? 0.1
    let maxLabels = (arguments["maxLabels"] as? Int) ?? 12

    DispatchQueue.global(qos: .userInitiated).async {
      let response = self.classifyAsset(
        assetId: assetId,
        fallbackPath: fallbackPath,
        confidenceThreshold: Float(confidenceThreshold),
        maxLabels: maxLabels
      )

      DispatchQueue.main.async {
        result(response)
      }
    }
  }

  private func classifyAsset(
    assetId: String,
    fallbackPath: String?,
    confidenceThreshold: Float,
    maxLabels: Int
  ) -> [String: Any] {
    do {
      let preparedImage = try prepareImageForClassification(
        assetId: assetId,
        fallbackPath: fallbackPath
      )

      guard preparedImage.cgImage.width > 0, preparedImage.cgImage.height > 0 else {
        throw ClassificationError(
          status: .requestFailed,
          stage: .visionRequestCreation,
          code: "invalid_bitmap_dimensions",
          message: "The prepared bitmap had invalid dimensions for Vision.",
          sourceFormat: preparedImage.sourceFormat,
          preparedFormat: preparedImage.preparedFormat,
          classificationRan: false,
          imagePreparationSucceeded: true
        )
      }

      let request = VNClassifyImageRequest()
      let handler = VNImageRequestHandler(cgImage: preparedImage.cgImage, options: [:])

      do {
        try handler.perform([request])
      } catch {
        throw ClassificationError(
          status: .requestFailed,
          stage: .visionExecution,
          code: "vision_execution_failed",
          message: "Vision could not execute image classification for this asset.",
          sourceFormat: preparedImage.sourceFormat,
          preparedFormat: preparedImage.preparedFormat,
          classificationRan: true,
          imagePreparationSucceeded: true
        )
      }

      let observations = (request.results as? [VNClassificationObservation] ?? [])
        .filter { $0.confidence >= confidenceThreshold }
        .sorted { $0.confidence > $1.confidence }
        .prefix(maxLabels)

      let labels = observations.map { observation in
        [
          "label": observation.identifier,
          "confidence": Double(observation.confidence),
          "modelIdentifier": classificationModelIdentifier,
        ]
      }

      if labels.isEmpty {
        return [
          "status": ClassificationStatus.noLabelsReturned.rawValue,
          "labels": labels,
          "failureReason": "Vision returned no labels above the current threshold.",
          "failureStage": NSNull(),
          "failureCode": NSNull(),
          "modelIdentifier": classificationModelIdentifier,
          "sourceFormat": flutterValue(preparedImage.sourceFormat),
          "preparedFormat": preparedImage.preparedFormat,
          "classificationRan": true,
          "imagePreparationSucceeded": true,
          "noLabelsReturned": true,
        ]
      }

      return [
        "status": ClassificationStatus.succeeded.rawValue,
        "labels": labels,
        "failureReason": NSNull(),
        "failureStage": NSNull(),
        "failureCode": NSNull(),
        "modelIdentifier": classificationModelIdentifier,
        "sourceFormat": flutterValue(preparedImage.sourceFormat),
        "preparedFormat": preparedImage.preparedFormat,
        "classificationRan": true,
        "imagePreparationSucceeded": true,
        "noLabelsReturned": false,
      ]
    } catch let error as ClassificationError {
      return [
        "status": error.status.rawValue,
        "labels": [],
        "failureReason": error.errorDescription ?? "Unable to classify this asset on device.",
        "failureStage": flutterValue(error.stage.rawValue),
        "failureCode": flutterValue(error.code),
        "modelIdentifier": classificationModelIdentifier,
        "sourceFormat": flutterValue(error.sourceFormat),
        "preparedFormat": flutterValue(error.preparedFormat),
        "classificationRan": error.classificationRan,
        "imagePreparationSucceeded": error.imagePreparationSucceeded,
        "noLabelsReturned": false,
      ]
    } catch {
      return [
        "status": ClassificationStatus.requestFailed.rawValue,
        "labels": [],
        "failureReason": "The on-device classification bridge hit an unexpected failure.",
        "failureStage": ClassificationFailureStage.visionExecution.rawValue,
        "failureCode": "unexpected_classification_failure",
        "modelIdentifier": classificationModelIdentifier,
        "sourceFormat": NSNull(),
        "preparedFormat": NSNull(),
        "classificationRan": false,
        "imagePreparationSucceeded": false,
        "noLabelsReturned": false,
      ]
    }
  }

  private func prepareImageForClassification(
    assetId: String,
    fallbackPath: String?
  ) throws -> PreparedImage {
    let asset = try resolvePhotoAsset(assetId: assetId)

    if let asset {
      do {
        let loaded = try loadImageDataFromPhotoLibrary(asset: asset)
        return try prepareImageFromData(
          loaded.data,
          sourceFormat: loaded.sourceFormat,
          loadStrategy: loaded.loadStrategy
        )
      } catch let initialError as ClassificationError {
        do {
          let rendered = try loadRenderedImageFromPhotoLibrary(asset: asset)
          return try prepareImageFromRenderedImage(
            rendered.image,
            sourceFormat: rendered.sourceFormat,
            loadStrategy: rendered.loadStrategy
          )
        } catch let renderedError as ClassificationError {
          if let fallbackPath, !fallbackPath.isEmpty {
            let fallback = try loadImageDataFromFile(path: fallbackPath)
            return try prepareImageFromData(
              fallback.data,
              sourceFormat: fallback.sourceFormat,
              loadStrategy: fallback.loadStrategy
            )
          }

          throw renderedError.preferred(over: initialError)
        }
      }
    }

    guard let fallbackPath, !fallbackPath.isEmpty else {
      throw ClassificationError(
        status: .imagePreparationFailed,
        stage: .loadImageData,
        code: "photo_asset_not_found",
        message: "The photo asset could not be loaded from Apple Photos.",
        sourceFormat: nil,
        preparedFormat: nil,
        classificationRan: false,
        imagePreparationSucceeded: false
      )
    }

    let fallback = try loadImageDataFromFile(path: fallbackPath)
    return try prepareImageFromData(
      fallback.data,
      sourceFormat: fallback.sourceFormat,
      loadStrategy: fallback.loadStrategy
    )
  }

  private func resolvePhotoAsset(assetId: String) throws -> PHAsset? {
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetchResult.firstObject else {
      return nil
    }

    guard asset.mediaType == .image else {
      throw ClassificationError(
        status: .unsupportedAsset,
        stage: .loadImageData,
        code: "unsupported_asset_type",
        message: "This asset type is not currently classifiable on device.",
        sourceFormat: nil,
        preparedFormat: nil,
        classificationRan: false,
        imagePreparationSucceeded: false
      )
    }

    return asset
  }

  private func loadImageDataFromPhotoLibrary(asset: PHAsset) throws -> LoadedImageData {
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .none
    options.version = .current
    options.isNetworkAccessAllowed = true
    options.isSynchronous = false

    let semaphore = DispatchSemaphore(value: 0)
    var loadedData: Data?
    var loadedFormat: String?
    var requestError: ClassificationError?

    PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) {
      [weak self] data, dataUTI, _, info in
      defer { semaphore.signal() }

      if let isCancelled = info?[PHImageCancelledKey] as? Bool, isCancelled {
        requestError = ClassificationError(
          status: .requestFailed,
          stage: .loadImageData,
          code: "photo_request_cancelled",
          message: "Apple Photos canceled image-data loading before classification.",
          sourceFormat: nil,
          preparedFormat: nil,
          classificationRan: false,
          imagePreparationSucceeded: false
        )
        return
      }

      if let error = info?[PHImageErrorKey] as? Error {
        requestError = ClassificationError(
          status: .imagePreparationFailed,
          stage: .loadImageData,
          code: "photo_data_error",
          message: "Apple Photos could not load image data for this asset.",
          sourceFormat: nil,
          preparedFormat: nil,
          classificationRan: false,
          imagePreparationSucceeded: false
        )
        return
      }

      guard let self else {
        requestError = ClassificationError(
          status: .requestFailed,
          stage: .loadImageData,
          code: "bridge_deallocated",
          message: "The classification bridge was unavailable while loading image data.",
          sourceFormat: nil,
          preparedFormat: nil,
          classificationRan: false,
          imagePreparationSucceeded: false
        )
        return
      }

      guard let data else {
        requestError = ClassificationError(
          status: .imagePreparationFailed,
          stage: .loadImageData,
          code: "photo_data_missing",
          message: "Apple Photos did not return image data for this asset.",
          sourceFormat: nil,
          preparedFormat: nil,
          classificationRan: false,
          imagePreparationSucceeded: false
        )
        return
      }

      loadedData = data
      loadedFormat = self.resolveSourceFormat(data: data, explicitTypeIdentifier: dataUTI)
    }

    let waitResult = semaphore.wait(timeout: .now() + 20)
    if waitResult == .timedOut {
      throw ClassificationError(
        status: .requestFailed,
        stage: .loadImageData,
        code: "photo_data_timeout",
        message: "Apple Photos timed out while loading image data for classification.",
        sourceFormat: nil,
        preparedFormat: nil,
        classificationRan: false,
        imagePreparationSucceeded: false
      )
    }

    if let requestError {
      throw requestError
    }

    guard let loadedData else {
      throw ClassificationError(
        status: .imagePreparationFailed,
        stage: .loadImageData,
        code: "photo_data_unavailable",
        message: "No usable image data was returned by Apple Photos.",
        sourceFormat: nil,
        preparedFormat: nil,
        classificationRan: false,
        imagePreparationSucceeded: false
      )
    }

    return LoadedImageData(
      data: loadedData,
      sourceFormat: loadedFormat,
      loadStrategy: "photo_library_image_data"
    )
  }

  private func loadRenderedImageFromPhotoLibrary(asset: PHAsset) throws -> LoadedRenderedImage {
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .exact
    options.version = .current
    options.isNetworkAccessAllowed = true
    options.isSynchronous = false

    let maxDimension = max(asset.pixelWidth, asset.pixelHeight)
    let constrainedDimension = min(max(maxDimension, 512), visionMaxDimension)
    let targetSize = CGSize(width: constrainedDimension, height: constrainedDimension)

    let semaphore = DispatchSemaphore(value: 0)
    var loadedImage: UIImage?
    var requestError: ClassificationError?

    PHImageManager.default().requestImage(
      for: asset,
      targetSize: targetSize,
      contentMode: .aspectFit,
      options: options
    ) { image, info in
      defer { semaphore.signal() }

      if let isCancelled = info?[PHImageCancelledKey] as? Bool, isCancelled {
        requestError = ClassificationError(
          status: .requestFailed,
          stage: .loadImageData,
          code: "photo_render_cancelled",
          message: "Apple Photos canceled rendered-image loading before classification.",
          sourceFormat: nil,
          preparedFormat: nil,
          classificationRan: false,
          imagePreparationSucceeded: false
        )
        return
      }

      if let error = info?[PHImageErrorKey] as? Error {
        requestError = ClassificationError(
          status: .imagePreparationFailed,
          stage: .loadImageData,
          code: "photo_render_error",
          message: "Apple Photos could not render a classification image for this asset.",
          sourceFormat: nil,
          preparedFormat: nil,
          classificationRan: false,
          imagePreparationSucceeded: false
        )
        return
      }

      if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
        requestError = ClassificationError(
          status: .imagePreparationFailed,
          stage: .loadImageData,
          code: "photo_render_degraded",
          message: "Apple Photos only returned a degraded preview for this asset.",
          sourceFormat: nil,
          preparedFormat: nil,
          classificationRan: false,
          imagePreparationSucceeded: false
        )
        return
      }

      guard let image else {
        requestError = ClassificationError(
          status: .imagePreparationFailed,
          stage: .loadImageData,
          code: "photo_render_missing",
          message: "Apple Photos could not produce a rendered image for this asset.",
          sourceFormat: nil,
          preparedFormat: nil,
          classificationRan: false,
          imagePreparationSucceeded: false
        )
        return
      }

      loadedImage = image
    }

    let waitResult = semaphore.wait(timeout: .now() + 20)
    if waitResult == .timedOut {
      throw ClassificationError(
        status: .requestFailed,
        stage: .loadImageData,
        code: "photo_render_timeout",
        message: "Apple Photos timed out while rendering a classification image.",
        sourceFormat: nil,
        preparedFormat: nil,
        classificationRan: false,
        imagePreparationSucceeded: false
      )
    }

    if let requestError {
      throw requestError
    }

    guard let loadedImage else {
      throw ClassificationError(
        status: .imagePreparationFailed,
        stage: .loadImageData,
        code: "photo_render_unavailable",
        message: "No rendered image was available for this photo-library asset.",
        sourceFormat: nil,
        preparedFormat: nil,
        classificationRan: false,
        imagePreparationSucceeded: false
      )
    }

    return LoadedRenderedImage(
      image: loadedImage,
      sourceFormat: nil,
      loadStrategy: "photo_library_rendered_image"
    )
  }

  private func loadImageDataFromFile(path: String) throws -> LoadedImageData {
    let url = URL(fileURLWithPath: path)

    do {
      let data = try Data(contentsOf: url, options: [.mappedIfSafe])
      let explicitTypeIdentifier = UTType(filenameExtension: url.pathExtension)?.identifier
      return LoadedImageData(
        data: data,
        sourceFormat: resolveSourceFormat(data: data, explicitTypeIdentifier: explicitTypeIdentifier),
        loadStrategy: "fallback_file_data"
      )
    } catch {
      throw ClassificationError(
        status: .imagePreparationFailed,
        stage: .loadImageData,
        code: "fallback_file_read_failed",
        message: "The fallback image file could not be read for classification.",
        sourceFormat: nil,
        preparedFormat: nil,
        classificationRan: false,
        imagePreparationSucceeded: false
      )
    }
  }

  private func prepareImageFromData(
    _ data: Data,
    sourceFormat: String?,
    loadStrategy: String
  ) throws -> PreparedImage {
    if let cgImage = try decodeCGImageFromData(data) {
      return try buildPreparedImage(
        from: cgImage,
        sourceFormat: sourceFormat,
        preparedFormat: "\(loadStrategy)_cgimage_bitmap_rgba8"
      )
    }

    guard let uiImage = UIImage(data: data) else {
      throw ClassificationError(
        status: .imagePreparationFailed,
        stage: .createUIImage,
        code: "uiimage_decode_failed",
        message: "The image data could not be decoded into a UIImage for classification.",
        sourceFormat: sourceFormat,
        preparedFormat: nil,
        classificationRan: false,
        imagePreparationSucceeded: false
      )
    }

    return try prepareImageFromRenderedImage(
      uiImage,
      sourceFormat: sourceFormat,
      loadStrategy: "\(loadStrategy)_uiimage_fallback"
    )
  }

  private func prepareImageFromRenderedImage(
    _ image: UIImage,
    sourceFormat: String?,
    loadStrategy: String
  ) throws -> PreparedImage {
    let normalized = try normalizeForVision(image)

    if let cgImage = normalized.cgImage {
      return try buildPreparedImage(
        from: cgImage,
        sourceFormat: sourceFormat,
        preparedFormat: "\(loadStrategy)_normalized_bitmap_rgba8"
      )
    }

    if let ciImage = normalized.ciImage {
      let context = CIContext(options: nil)
      if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
        return try buildPreparedImage(
          from: cgImage,
          sourceFormat: sourceFormat,
          preparedFormat: "\(loadStrategy)_ci_bitmap_rgba8"
        )
      }
    }

    if let encodedFallback = encodeNormalizedImageFallback(normalized) {
      if let cgImage = try decodeCGImageFromData(encodedFallback.data) {
        return try buildPreparedImage(
          from: cgImage,
          sourceFormat: sourceFormat,
          preparedFormat: "\(loadStrategy)_\(encodedFallback.label)_bitmap_rgba8"
        )
      }
    }

    throw ClassificationError(
      status: .imagePreparationFailed,
      stage: .createBitmap,
      code: "cgimage_creation_failed",
      message: "The normalized image could not be converted into a CGImage.",
      sourceFormat: sourceFormat,
      preparedFormat: nil,
      classificationRan: false,
      imagePreparationSucceeded: false
    )
  }

  private func decodeCGImageFromData(_ data: Data) throws -> CGImage? {
    guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
      return nil
    }

    let options: [CFString: Any] = [
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: visionMaxDimension,
    ]

    if let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
      return thumbnail
    }

    if let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
      return cgImage
    }

    return nil
  }

  private func encodeNormalizedImageFallback(_ image: UIImage) -> (data: Data, label: String)? {
    if imageHasAlpha(image), let pngData = image.pngData() {
      return (pngData, "png_reencode")
    }

    if let jpegData = image.jpegData(compressionQuality: 0.96) {
      return (jpegData, "jpeg_reencode")
    }

    if let pngData = image.pngData() {
      return (pngData, "png_reencode")
    }

    return nil
  }

  private func normalizeForVision(_ image: UIImage) throws -> UIImage {
    guard image.size.width > 0, image.size.height > 0 else {
      throw ClassificationError(
        status: .imagePreparationFailed,
        stage: .normalizeImage,
        code: "invalid_image_dimensions",
        message: "The decoded image had invalid dimensions for classification.",
        sourceFormat: nil,
        preparedFormat: nil,
        classificationRan: false,
        imagePreparationSucceeded: false
      )
    }

    let targetSize = constrainedSize(for: image.size, maxDimension: CGFloat(visionMaxDimension))
    let format = UIGraphicsImageRendererFormat.preferred()
    format.scale = 1
    format.opaque = false

    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }
  }

  private func buildPreparedImage(
    from cgImage: CGImage,
    sourceFormat: String?,
    preparedFormat: String
  ) throws -> PreparedImage {
    let width = cgImage.width
    let height = cgImage.height

    guard width > 0, height > 0 else {
      throw ClassificationError(
        status: .imagePreparationFailed,
        stage: .createBitmap,
        code: "bitmap_dimensions_invalid",
        message: "The image could not be converted into a valid bitmap.",
        sourceFormat: sourceFormat,
        preparedFormat: nil,
        classificationRan: false,
        imagePreparationSucceeded: false
      )
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    guard let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: bitmapInfo
    ) else {
      throw ClassificationError(
        status: .imagePreparationFailed,
        stage: .createBitmap,
        code: "bitmap_context_creation_failed",
        message: "The app could not create a bitmap context for classification.",
        sourceFormat: sourceFormat,
        preparedFormat: nil,
        classificationRan: false,
        imagePreparationSucceeded: false
      )
    }

    context.interpolationQuality = .high
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let preparedCGImage = context.makeImage() else {
      throw ClassificationError(
        status: .imagePreparationFailed,
        stage: .createBitmap,
        code: "bitmap_image_creation_failed",
        message: "The app could not finalize a Vision-ready bitmap for this asset.",
        sourceFormat: sourceFormat,
        preparedFormat: nil,
        classificationRan: false,
        imagePreparationSucceeded: false
      )
    }

    return PreparedImage(
      cgImage: preparedCGImage,
      sourceFormat: sourceFormat,
      preparedFormat: preparedFormat
    )
  }

  private func imageHasAlpha(_ image: UIImage) -> Bool {
    guard let alphaInfo = image.cgImage?.alphaInfo else {
      return false
    }

    switch alphaInfo {
    case .first, .last, .premultipliedFirst, .premultipliedLast:
      return true
    case .none, .noneSkipFirst, .noneSkipLast, .alphaOnly:
      return false
    @unknown default:
      return false
    }
  }

  private func constrainedSize(for size: CGSize, maxDimension: CGFloat) -> CGSize {
    let longestSide = max(size.width, size.height)
    guard longestSide > maxDimension, longestSide > 0 else {
      return size
    }

    let scale = maxDimension / longestSide
    return CGSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
  }

  private func resolveSourceFormat(data: Data, explicitTypeIdentifier: String?) -> String? {
    if let explicitTypeIdentifier, !explicitTypeIdentifier.isEmpty {
      return explicitTypeIdentifier
    }

    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let type = CGImageSourceGetType(source)
    else {
      return nil
    }

    return type as String
  }

  private func flutterValue(_ value: String?) -> Any {
    value ?? NSNull()
  }
}

private struct PreparedImage {
  let cgImage: CGImage
  let sourceFormat: String?
  let preparedFormat: String
}

private struct LoadedImageData {
  let data: Data
  let sourceFormat: String?
  let loadStrategy: String
}

private struct LoadedRenderedImage {
  let image: UIImage
  let sourceFormat: String?
  let loadStrategy: String
}

private enum ClassificationStatus: String {
  case succeeded
  case unsupportedAsset
  case imagePreparationFailed
  case noLabelsReturned
  case requestFailed
}

private enum ClassificationFailureStage: String {
  case loadImageData = "load_image_data"
  case createUIImage = "create_uiimage"
  case normalizeImage = "normalize_image"
  case createBitmap = "create_bitmap"
  case visionRequestCreation = "vision_request_creation"
  case visionExecution = "vision_execution"
}

private struct ClassificationError: LocalizedError {
  init(
    status: ClassificationStatus,
    stage: ClassificationFailureStage,
    code: String,
    message: String,
    sourceFormat: String?,
    preparedFormat: String?,
    classificationRan: Bool,
    imagePreparationSucceeded: Bool
  ) {
    self.status = status
    self.stage = stage
    self.code = code
    self.message = message
    self.sourceFormat = sourceFormat
    self.preparedFormat = preparedFormat
    self.classificationRan = classificationRan
    self.imagePreparationSucceeded = imagePreparationSucceeded
  }

  let status: ClassificationStatus
  let stage: ClassificationFailureStage
  let code: String
  let message: String
  let sourceFormat: String?
  let preparedFormat: String?
  let classificationRan: Bool
  let imagePreparationSucceeded: Bool

  var errorDescription: String? {
    message
  }

  func preferred(over other: ClassificationError) -> ClassificationError {
    if stage == .createBitmap || stage == .visionExecution || stage == .visionRequestCreation {
      return self
    }

    if other.stage == .createBitmap || other.stage == .visionExecution || other.stage == .visionRequestCreation {
      return other
    }

    return self
  }
}
