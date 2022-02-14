//
//  FoodCalorieEstimator.swift
//  TrueDepthStreamer
//
//  Created by Kento Adachi on 2021/12/20.
//  Copyright © 2021 Apple. All rights reserved.
//

import Foundation
import CoreML
import Accelerate

@available(iOS 14.0, *)
class CalorieEstimator{
    
    
    var massRegressionModel : MassRegModelGray_with_metadata? = nil
    var viewController : CameraViewController
    
    
    init(controller: CameraViewController){
        self.massRegressionModel = MassRegModelGray_with_metadata()
        self.viewController = controller
    }
    
    func caliculateAverageDepth(depthFrame : CVPixelBuffer,mask : MLMultiArray) -> Float{
        var total : Float = 0
        var ctr = 0
        for y in 0 ..< mask.shape[0].intValue {
            for x in 0 ..< mask.shape[1].intValue {
                if (mask[y * mask.shape[1].intValue + x] != 0){
                    let depthPoint = CGPoint(x: x, y: y)
                    CVPixelBufferLockBaseAddress(depthFrame, .readOnly)
                    let rowData = CVPixelBufferGetBaseAddress(depthFrame)! + Int(depthPoint.y) * CVPixelBufferGetBytesPerRow(depthFrame)
                    // swift does not have an Float16 data type. Use UInt16 instead, and then translate
                    var f16Pixel = rowData.assumingMemoryBound(to: UInt16.self)[Int(depthPoint.x)]
                    CVPixelBufferUnlockBaseAddress(depthFrame, .readOnly)
                    
                    var f32Pixel = Float(0.0)
                    var src = vImage_Buffer(data: &f16Pixel, height: 1, width: 1, rowBytes: 2)
                    var dst = vImage_Buffer(data: &f32Pixel, height: 1, width: 1, rowBytes: 4)
                    vImageConvert_Planar16FtoPlanarF(&src, &dst, 0)
                    
                    if(!f32Pixel.isNaN && f32Pixel*100 > 10 && f32Pixel*100 < 200){
                        total += f32Pixel
                        ctr += 1
                    }
                    
                    // Convert the depth frame format to cm
//                    let depthString = String(format: "%.2f cm", f32Pixel * 100)
                }
            }
        }
        return total*100 / Float(ctr)
    }
    
//    @available(iOS 14.0, *)
    func predictMass(pixelCount:Int, aveDepth:Float, category:Int) -> Float{
//        let inputArray = try! MLMultiArray(shape: [10], dataType: .float)
        
        let cat1 : Float = (category == 1) ? 1 : 0
        let cat2 : Float = (category == 2) ? 1 : 0
        let cat3 : Float = (category == 3) ? 1 : 0
        let cat4 : Float = (category == 4) ? 1 : 0
        let cat5 : Float = (category == 5) ? 1 : 0
        
        let inputArray = try! MLMultiArray([aveDepth,Float(pixelCount),0,cat1,cat2,cat3,cat4,cat5])
//        do{
        let out = try! self.massRegressionModel?.prediction(inp: inputArray)
        let mass = out!._20[0]
//        self.viewController.currentState = "tracking"
        self.viewController.setCurrentState(state: "tracking")
//            print("reg")
        return mass.floatValue
//        } catch {
//            print(error)
//        }
        
    }
    
    func convertMassToCalorie(mass: Float, category: Int) -> Float{
        var amp : Float = 0
        switch category {
        case 1:
            amp = 4.51
        case 2:
            amp = 0.54
        case 3:
            amp = 1.05
        case 4:
            amp = 1.03
        case 5:
            amp = 1.56
        default:
            amp = 0
        }
        return mass * amp
    }
    
    
    
}
