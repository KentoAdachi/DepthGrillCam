//
//  DepthMap.swift
//  TrueDepthStreamer
//
//  Created by Kento Adachi on 2021/04/20.
//  Copyright © 2021 Apple. All rights reserved.
//

import Foundation
import Accelerate

import VideoToolbox


class DepthMap {
    var raw : CVPixelBuffer
    init(depthPixelBuffer : CVPixelBuffer) {
        self.raw = depthPixelBuffer
    }
    func getDepth(x : Int , y:Int)-> Float32{
        let depthPoint = CGPoint(x: x,y: y)
        return getDepth(depthPoint: depthPoint)
    }
    func getDepth(depthPoint: CGPoint) -> Float32 {
        
        let depthPixelBuffer = self.raw
        print(depthPoint.debugDescription)
        
        assert(kCVPixelFormatType_DepthFloat16 == CVPixelBufferGetPixelFormatType(depthPixelBuffer))
        CVPixelBufferLockBaseAddress(depthPixelBuffer, .readOnly)
        let rowData = CVPixelBufferGetBaseAddress(depthPixelBuffer)! + Int(depthPoint.y) * CVPixelBufferGetBytesPerRow(depthPixelBuffer)
        // swift does not have an Float16 data type. Use UInt16 instead, and then translate
        var f16Pixel = rowData.assumingMemoryBound(to: UInt16.self)[Int(depthPoint.x)]
        CVPixelBufferUnlockBaseAddress(depthPixelBuffer, .readOnly)
        
        var f32Pixel = Float(0.0)
        var src = vImage_Buffer(data: &f16Pixel, height: 1, width: 1, rowBytes: 2)
        var dst = vImage_Buffer(data: &f32Pixel, height: 1, width: 1, rowBytes: 4)
        vImageConvert_Planar16FtoPlanarF(&src, &dst, 0)
        
        // Convert the depth frame format to cm
        let depthString = String(format: "%.2f cm", f32Pixel * 100)
//        let depthImage = CIImage(cvPixelBuffer: self.raw)
//        let context = CIContext(options: nil)
//        let cgImage =  context.createCGImage(depthImage, from: depthImage.extent)
        
        print(depthString)
        
        return f32Pixel
    }
    
    func getCGImage() -> CGImage{
        let depthPixelBuffer = self.raw
        let depthImage = CIImage(cvPixelBuffer: depthPixelBuffer,options: [:])
        let context = CIContext(options: nil)
        let cgImage =  context.createCGImage(depthImage, from: depthImage.extent)!
        return cgImage
    }
    
    func compileToWritableBuffer()-> CVPixelBuffer{
        let depthPixelBuffer = self.raw
        
//        let image :CGImage
//        var cgImageWrapper : CGImage?
//        VTCreateCGImageFromCVPixelBuffer(depthPixelBuffer, options: nil, imageOut: &cgImageWrapper)
//
//        guard let image : CGImage = cgImageWrapper else {return depthPixelBuffer}
        
        let fordeb = CIImage(cvPixelBuffer: depthPixelBuffer)
        
        let pixelBuffer = fordeb.pixelBuffer(cgSize: CGSize(width: 640, height: 480))
//        let image = self.getCGImage()
//
//        guard let imageData = image.dataProvider?.data else { return depthPixelBuffer }
//        let width =  image.width
//        let height = image.height
//        let bytesPerRow = image.bytesPerRow
//        let options: NSDictionary = [:]
//        var pixelBuffer: CVPixelBuffer? = nil
//
//        let imageCFData = CFDataCreateMutableCopy(kCFAllocatorDefault, 0, imageData)
//        let imageCFDataPtr = CFDataGetMutableBytePtr(imageCFData)
//
//        CVPixelBufferCreateWithBytes(
//           kCFAllocatorDefault,
//           width,
//           height,
//           kCVPixelFormatType_32ARGB,
//           imageCFDataPtr!,
//           bytesPerRow,
//           nil,
//           nil,
//           options,
//           &pixelBuffer
//        )
        let fordeb2 = CIImage(cvPixelBuffer: pixelBuffer!)
        
        return pixelBuffer!
    }
    
    func set(depthPoint: CGPoint) -> Bool{
        return false
    }
    
    func createMaskFromDepth(handPoint:CGPoint, threshold:Float) -> CGImage{
        let depth :Float = getDepth(depthPoint: handPoint)
        
        let depthPixelBuffer = self.raw
//        depthPixelBuffer.binarize(cutOff: 0.5)
        
        let depthImage = CIImage(cvPixelBuffer: depthPixelBuffer,options: [:])
        
        let context = CIContext(options: nil)
        let cgImage =  context.createCGImage(depthImage, from: depthImage.extent)!
        
        print(cgImage.isMask)
        
        
        let binImage: CGImage = OpenCVWrapper.binarize(cgImage,handPoint)!.takeRetainedValue()
        
        let uiImage = UIImage.init(cgImage: binImage)
        
        print("out")
        
//        let cgContext = CGContext.init(data: nil, width: mask.width, height: mask.height, bitsPerComponent: mask.bitsPerComponent, bytesPerRow: mask.bytesPerRow, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: mask.bitmapInfo.rawValue)
//
//        let maskImage : CGImage = (cgContext?.makeImage())!
        
        
        
        
        return binImage
    }
}

//shuさんソースより
extension CVPixelBuffer {
    
    func binarize(cutOff: Float) {
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        for yMap in 0 ..< height {
            let rowData = CVPixelBufferGetBaseAddress(self)! + yMap * CVPixelBufferGetBytesPerRow(self)
            let data = UnsafeMutableBufferPointer<Float32>(start: rowData.assumingMemoryBound(to: Float32.self), count: width)
            for index in 0 ..< width {
                let depth = data[index]
                if depth.isNaN {
                    data[index] = 1.0
                } else if depth <= cutOff {
                    // 前景
                    data[index] = 1.0
                } else {
                    // 背景
                    data[index] = 0.0
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
    }
}

extension CIImage {
    func pixelBuffer(cgSize size:CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        let width:Int = Int(size.width)
        let height:Int = Int(size.height)

        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            height,
                            kCVPixelFormatType_32BGRA,
                            attrs,
                            &pixelBuffer)

        // put bytes into pixelBuffer
        let context = CIContext()
        context.render(self, to: pixelBuffer!)
        return pixelBuffer
    }
}
