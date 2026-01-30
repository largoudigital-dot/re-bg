//
//  ImageProcessor.swift
//  re-bg
//
//  Created by Photo Editor
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

enum EffectType: String, CaseIterable, Identifiable {
    case none = "Original"
    case vignette = "Vignette"
    case bloom = "Bloom"
    case noir = "Noir"
    case crystal = "Kristall"
    case blur = "Unschärfe"
    case edges = "Kanten"
    case posterize = "Poster"
    case grain = "Körnung"
    
    var id: String { rawValue }
}

class ImageProcessor {
    private let context = CIContext()
    
    // Apply filter to image
    func applyFilter(_ filterType: FilterType, to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let filteredImage: CIImage?
        
        switch filterType {
        case .none:
            filteredImage = ciImage
            
        case .losAngeles:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.saturation = 1.3
            filter.brightness = 0.02
            let warmFilter = CIFilter.temperatureAndTint()
            warmFilter.inputImage = filter.outputImage
            warmFilter.neutral = CIVector(x: 6500, y: 0)
            warmFilter.targetNeutral = CIVector(x: 7500, y: 0)
            filteredImage = warmFilter.outputImage
            
        case .paris:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.brightness = 0.05
            filter.saturation = 1.1
            let softFilter = CIFilter.temperatureAndTint()
            softFilter.inputImage = filter.outputImage
            softFilter.neutral = CIVector(x: 6500, y: 0)
            softFilter.targetNeutral = CIVector(x: 5800, y: 10) // Light pink/soft tint
            filteredImage = softFilter.outputImage
            
        case .tokyo:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.contrast = 1.25
            filter.saturation = 1.1
            let coolFilter = CIFilter.temperatureAndTint()
            coolFilter.inputImage = filter.outputImage
            coolFilter.neutral = CIVector(x: 6500, y: 0)
            coolFilter.targetNeutral = CIVector(x: 4800, y: 0)
            filteredImage = coolFilter.outputImage

        case .london:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.saturation = 0.6
            filter.contrast = 0.9
            let moodyFilter = CIFilter.temperatureAndTint()
            moodyFilter.inputImage = filter.outputImage
            moodyFilter.neutral = CIVector(x: 6500, y: 0)
            moodyFilter.targetNeutral = CIVector(x: 5200, y: 0)
            filteredImage = moodyFilter.outputImage

        case .newYork:
            let mono = CIFilter.photoEffectNoir()
            mono.inputImage = ciImage
            let contrast = CIFilter.colorControls()
            contrast.inputImage = mono.outputImage
            contrast.contrast = 1.5
            filteredImage = contrast.outputImage

        case .milan:
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.saturation = 1.6
            filter.contrast = 1.1
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = filter.outputImage
            sharpen.sharpness = 0.8
            filteredImage = sharpen.outputImage

        case .sepia:
            let filter = CIFilter.sepiaTone()
            filter.inputImage = ciImage
            filter.intensity = 0.8
            filteredImage = filter.outputImage
            
        case .dramatic:
            let filter = CIFilter.photoEffectChrome()
            filter.inputImage = ciImage
            let contrastFilter = CIFilter.colorControls()
            contrastFilter.inputImage = filter.outputImage
            contrastFilter.contrast = 1.2
            filteredImage = contrastFilter.outputImage
        }
        
        guard let outputImage = filteredImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // Apply adjustments to image
    func applyAdjustments(to image: UIImage,
                         brightness: Double,
                         contrast: Double,
                         saturation: Double,
                         blur: Double) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }
        
        var currentImage = ciImage
        
        // Apply color controls (brightness, contrast, saturation)
        let colorFilter = CIFilter.colorControls()
        colorFilter.inputImage = currentImage
        colorFilter.brightness = Float(brightness - 1.0) // Convert 0-2 range to -1 to 1
        colorFilter.contrast = Float(contrast)
        colorFilter.saturation = Float(saturation)
        
        if let output = colorFilter.outputImage {
            currentImage = output
        }
        
        // Apply blur if needed
        if blur > 0 {
            let blurFilter = CIFilter.gaussianBlur()
            blurFilter.inputImage = currentImage
            blurFilter.radius = Float(blur)
            
            if let output = blurFilter.outputImage {
                currentImage = output
            }
        }
        
        guard let cgImage = context.createCGImage(currentImage, from: ciImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // Rotate image
    func rotateImage(_ image: UIImage, degrees: CGFloat) -> UIImage? {
        let radians = degrees * .pi / 180
        
        var newSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .size
        
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        image.draw(in: CGRect(x: -image.size.width / 2,
                             y: -image.size.height / 2,
                             width: image.size.width,
                             height: image.size.height))
        
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }
    
    // Crop image
    func cropImage(_ image: UIImage, to ratio: CGFloat) -> UIImage? {
        let cgImage = image.cgImage!
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        let currentRatio = width / height
        var newWidth = width
        var newHeight = height
        
        if currentRatio > ratio {
            // Image is wider than target ratio
            newWidth = height * ratio
        } else {
            // Image is taller than target ratio
            newHeight = width / ratio
        }
        
        let x = (width - newWidth) / 2
        let y = (height - newHeight) / 2
        
        // x, y, newWidth, newHeight are already in pixels (from cgImage.width/height)
        let cropRect = CGRect(x: x, y: y, width: newWidth, height: newHeight)
        
        guard let croppedCgImage = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: croppedCgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // Crop to custom size
    func cropToSize(_ image: UIImage, width targetWidth: CGFloat, height targetHeight: CGFloat) -> UIImage? {
        let ratio = targetWidth / targetHeight
        return cropImage(image, to: ratio)
    }
    
    // Process complete image with all settings
    func processImage(original: UIImage,
                     filter: FilterType,
                     brightness: Double,
                     contrast: Double,
                     saturation: Double,
                     blur: Double,
                     rotation: CGFloat) -> UIImage? {
        var processedImage = original
        
        // Apply filter first
        if let filtered = applyFilter(filter, to: processedImage) {
            processedImage = filtered
        }
        
        // Apply adjustments
        if let adjusted = applyAdjustments(to: processedImage,
                                          brightness: brightness,
                                          contrast: contrast,
                                          saturation: saturation,
                                          blur: blur) {
            processedImage = adjusted
        }
        
        // Apply rotation
        if rotation != 0 {
            if let rotated = rotateImage(processedImage, degrees: rotation) {
                processedImage = rotated
            }
        }
        
        return processedImage
    }
    func processImageWithCrop(original: UIImage,
                              filter: FilterType,
                              brightness: Double,
                              contrast: Double,
                              saturation: Double,
                              blur: Double,
                              rotation: CGFloat,
                              aspectRatio: CGFloat?,
                              customSize: CGSize?,
                              backgroundColor: Color?,
                              gradientColors: [Color]?,
                              backgroundImage: UIImage?,
                              cropRect: CGRect? = nil,
                              stickers: [Sticker] = [],
                              textItems: [TextItem] = []) -> UIImage? {
        var processedImage = original
        
        // 0. Apply normalized crop rect if provided (Free Crop)
        if let rect = cropRect {
             guard let cgImage = processedImage.cgImage else { return processedImage }
             
             // IMPORTANT: Use UIImage.size which accounts for orientation,
             // not cgImage.width/height which are raw pixel dimensions
             let imageSize = processedImage.size
             
             // Convert normalized coordinates (0-1) to actual pixel coordinates
             let x = rect.minX * imageSize.width
             let y = rect.minY * imageSize.height
             let w = rect.width * imageSize.width
             let h = rect.height * imageSize.height
             
             // Create crop rectangle in image coordinate space
             let cropZone = CGRect(x: x, y: y, width: w, height: h)
             
             // Scale the crop zone to match the actual CGImage pixel dimensions
             let scale = processedImage.scale
             let scaledCropZone = CGRect(
                 x: cropZone.origin.x * scale,
                 y: cropZone.origin.y * scale,
                 width: cropZone.size.width * scale,
                 height: cropZone.size.height * scale
             )
             
             if let croppedCg = cgImage.cropping(to: scaledCropZone) {
                 processedImage = UIImage(cgImage: croppedCg, scale: processedImage.scale, orientation: processedImage.imageOrientation)
             }
        }
        
        // 1. Crop foreground first if needed
        if let ratio = aspectRatio {
            if let cropped = cropImage(processedImage, to: ratio) {
                processedImage = cropped
            }
        } else if let size = customSize {
            if let cropped = cropToSize(processedImage, width: size.width, height: size.height) {
                processedImage = cropped
            }
        }
        
        // 2. Apply all other effects to foreground
        var finalForeground = processImage(original: processedImage,
                                          filter: filter,
                                          brightness: brightness,
                                          contrast: contrast,
                                          saturation: saturation,
                                          blur: blur,
                                          rotation: rotation) ?? processedImage
        
        if let background = backgroundImage {
            processedImage = composite(foreground: finalForeground, background: background) ?? finalForeground
        } else if let colors = gradientColors {
            if let gradientBg = self.createGradientImage(colors: colors, size: finalForeground.size) {
                processedImage = composite(foreground: finalForeground, background: gradientBg) ?? finalForeground
            }
        } else if let color = backgroundColor {
            if let colorBg = self.createColorImage(color: color, size: finalForeground.size) {
                processedImage = composite(foreground: finalForeground, background: colorBg) ?? finalForeground
            }
        } else {
            processedImage = finalForeground
        }
        
        // 4. Render Stickers
        if !stickers.isEmpty {
            processedImage = renderStickers(stickers, onto: processedImage) ?? processedImage
        }
        
        // 5. Render Text Items
        if !textItems.isEmpty {
            processedImage = renderTextItems(textItems, onto: processedImage) ?? processedImage
        }
        
        return processedImage
    }
    
    private func renderStickers(_ stickers: [Sticker], onto image: UIImage) -> UIImage? {
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        
        image.draw(in: CGRect(origin: .zero, size: size))
        
        let context = UIGraphicsGetCurrentContext()
        
        for sticker in stickers {
            let stickerSize = size.width * 0.15 * sticker.scale // Base size is 15% of width
            let x = sticker.position.x * size.width
            let y = sticker.position.y * size.height
            
            context?.saveGState()
            context?.translateBy(x: x, y: y)
            context?.rotate(by: CGFloat(sticker.rotation.radians))
            
            let rect = CGRect(x: -stickerSize / 2, y: -stickerSize / 2, width: stickerSize, height: stickerSize)
            
            let string = sticker.content as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: stickerSize * 0.8)
            ]
            
            string.draw(in: rect, withAttributes: attributes)
            
            context?.restoreGState()
        }
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    private func renderTextItems(_ items: [TextItem], onto image: UIImage) -> UIImage? {
        let size = image.size
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        
        image.draw(in: CGRect(origin: .zero, size: size))
        
        let context = UIGraphicsGetCurrentContext()
        
        for item in items {
            // Determine font and size (base it on image width)
            let fontSize = size.width * 0.08 * item.scale
            let font = UIFont(name: item.fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize, weight: .bold)
            
            // Calculate text size and layout
            let paragraphStyle = NSMutableParagraphStyle()
            switch item.alignment {
            case .left: paragraphStyle.alignment = .left
            case .center: paragraphStyle.alignment = .center
            case .right: paragraphStyle.alignment = .right
            }
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(item.color),
                .paragraphStyle: paragraphStyle
            ]
            
            let attributedString = NSAttributedString(string: item.text, attributes: attributes)
            let textSize = attributedString.size()
            
            // Background padding
            let padding = fontSize * 0.4
            let bgRect = CGRect(x: -textSize.width/2 - padding, 
                                y: -textSize.height/2 - padding/2, 
                                width: textSize.width + padding * 2, 
                                height: textSize.height + padding)
            
            let x = item.position.x * size.width
            let y = item.position.y * size.height
            
            context?.saveGState()
            context?.translateBy(x: x, y: y)
            context?.rotate(by: CGFloat(item.rotation.radians))
            
            // Draw background if needed
            if item.backgroundStyle != .none {
                let opacity = item.backgroundStyle == .solid ? 1.0 : 0.6
                UIColor(item.backgroundColor).withAlphaComponent(opacity).setFill()
                let path = UIBezierPath(roundedRect: bgRect, cornerRadius: padding * 0.5)
                path.fill()
            }
            
            // Draw text
            let textRect = CGRect(x: -textSize.width/2, y: -textSize.height/2, width: textSize.width, height: textSize.height)
            attributedString.draw(in: textRect)
            
            context?.restoreGState()
        }
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    private func createColorImage(color: Color, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(color).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    private func createGradientImage(colors: [Color], size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgColors = colors.map { UIColor($0).cgColor }
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors as CFArray, locations: nil) else { return }
            
            context.cgContext.drawLinearGradient(gradient, start: CGPoint.zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
    }
    
    private func composite(foreground: UIImage, background: UIImage) -> UIImage? {
        let size = foreground.size
        UIGraphicsBeginImageContextWithOptions(size, false, foreground.scale)
        
        // Calculate aspect fill (cover) scale
        let widthRatio = size.width / background.size.width
        let heightRatio = size.height / background.size.height
        let scale = max(widthRatio, heightRatio)
        
        let newWidth = background.size.width * scale
        let newHeight = background.size.height * scale
        
        // Center the background
        let x = (size.width - newWidth) / 2
        let y = (size.height - newHeight) / 2
        
        let bgRect = CGRect(x: x, y: y, width: newWidth, height: newHeight)
        
        // Draw background with cover logic
        background.draw(in: bgRect)
        
        // Draw foreground on top
        foreground.draw(in: CGRect(origin: .zero, size: size))
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return result
    }
    
    // Core Effect logic
    func applyEffect(_ effect: EffectType, to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return image }
        var outputImage: CIImage?
        
        switch effect {
        case .none:
            return image
        case .vignette:
            let filter = CIFilter.vignette()
            filter.inputImage = ciImage
            filter.intensity = 1.0
            filter.radius = 2.0
            outputImage = filter.outputImage
        case .bloom:
            let filter = CIFilter.bloom()
            filter.inputImage = ciImage
            filter.intensity = 0.8
            filter.radius = 10.0
            outputImage = filter.outputImage
        case .noir:
            let filter = CIFilter.photoEffectNoir()
            filter.inputImage = ciImage
            outputImage = filter.outputImage
        case .crystal:
            let filter = CIFilter.gloom()
            filter.inputImage = ciImage
            filter.intensity = 1.0
            filter.radius = 10.0
            outputImage = filter.outputImage
        case .blur:
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = ciImage
            filter.radius = 10.0
            outputImage = filter.outputImage
        case .edges:
            let filter = CIFilter.edges()
            filter.inputImage = ciImage
            filter.intensity = 1.0
            outputImage = filter.outputImage
        case .posterize:
            let filter = CIFilter.colorPosterize()
            filter.inputImage = ciImage
            filter.levels = 6.0
            outputImage = filter.outputImage
        case .grain:
            // 1. Create random noise
            let noise = CIFilter.randomGenerator()
            let noiseImage = noise.outputImage?.cropped(to: ciImage.extent)
            
            // 2. Make it monochrome/grey
            let whiteNoise = CIFilter.colorMonochrome()
            whiteNoise.inputImage = noiseImage
            whiteNoise.color = CIColor.gray
            whiteNoise.intensity = 1.0
            
            // 3. Blend with original (Overlay or Soft Light look)
            let blend = CIFilter.overlayBlendMode()
            blend.inputImage = whiteNoise.outputImage
            blend.backgroundImage = ciImage
            
            // 4. Adjust intensity by blending back a bit
            outputImage = blend.outputImage
        }
        
        guard let result = outputImage,
              let cgImage = context.createCGImage(result, from: result.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
