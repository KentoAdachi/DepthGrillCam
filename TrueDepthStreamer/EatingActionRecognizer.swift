//
//  EatingActionRecognizer.swift
//  TrueDepthStreamer
//
//  Created by Kento Adachi on 2021/11/25.
//  Copyright © 2021 Apple. All rights reserved.
//

import Foundation
import UIKit
import Vision
import Accelerate

@available(iOS 14.0, *)
class EatingActionRecognizer{
    
    //    private let request:VNDetectFaceLandmarksRequest = VNDetectFaceLandmarksRequest()
    //    var controller : CameraViewController
    //
    //
    //    init(controller : CameraViewController){
    //        self.controller = controller
    //    }
    //
    //    private func getMask()->CGImage?{
    //        return self.controller.getMask()
    //    }
    //    private func getImage()->CIImage?{
    //        return self.controller.getImage()
    //    }
    var faceLandmarkRequest : VNDetectFaceLandmarksRequest?
    var mask : MLMultiArray?
    var isFaceDetectable : Bool = true
    
    var sequenceRequestHandler : VNSequenceRequestHandler?
//    var objectTrackingRequest : VNTrackObjectRequest?
    var inputObservation : VNDetectedObjectObservation?
    var isFoodTrackable : Bool = true
    var isFoodTracking : Bool = false
    var controller : CameraViewController
    var boundingbox : CGRect? = nil
    
    var foodCount : Int = 0
    var totalCalorie : Float = 0
    
    var depth : CVPixelBuffer? = nil
    
//    let duration = 100
//    var ctr = 100
    
    
    
    init(controller : CameraViewController) {
        //        self.request = VNDetectFaceLandmarksRequest(completionHandler: requestDidComplete)
        self.controller = controller
        setupModel()
        
    }
    func setInputObservation(boundingbox : CGRect){
        self.inputObservation = VNDetectedObjectObservation(boundingBox: boundingbox)
//        self.objectTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: inputObservation!, completionHandler: trackingRequestDidComplete)
    }
    private func setupModel(){
        self.faceLandmarkRequest = VNDetectFaceLandmarksRequest(completionHandler: faceRequestDidComplete)
        let input = VNDetectedObjectObservation(boundingBox: CGRect(x: 0.0, y: 0.0, width: 0.2, height: 0.2))
        self.inputObservation = input
        
//        self.objectTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: self.inputObservation! , completionHandler: trackingRequestDidComplete(request:error:))
        self.sequenceRequestHandler = VNSequenceRequestHandler()
        Timer.scheduledTimer(withTimeInterval: 0.33, repeats: true, block: {(timer) in
            self.isFoodTrackable = true
        })
    }
    func trackingRequestDidComplete(request: VNRequest, error:Error?){
//        self.isFoodTrackable = true
        guard let observation = request.results?.first as? VNDetectedObjectObservation else {
            self.isFoodTracking = false
            
            return
        }
        self.inputObservation = observation
//        print(observation.boundingBox)
        self.isFoodTracking = true
        
//        var m2 : MLMultiArray = self.controller.segmentator!.getMask()!
//        for y in Int(observation.boundingBox.minY * 480) ..< Int((observation.boundingBox.height + observation.boundingBox.minY) * 480){
//            for x in Int(observation.boundingBox.minX * 640) ..< Int((observation.boundingBox.height + observation.boundingBox.minX) * 640){
//                m2[y * (self.controller.segmentator!.getMask()! as MLMultiArray).shape[1].intValue + x] = 255
//            }
//            
//        }
////        let m2i = m2.image()
//        DispatchQueue.main.async {
//            let mi2 = m2.image()!
////            self.mask = mask
//            self.controller.segmentator?.updateResultView(maskImage: mi2)
//        }
//        print("mask")
        
        
        //trackingrequest はその都度作り直さなければいけないかも
//        print(observation)
    }
    //口の深度をとる関数
    
    func faceRequestDidComplete(request: VNRequest, error: Error?){
        
        DispatchQueue.global(qos: .utility).async {
//            self.isFaceDetectable = true
//            print("async")
            guard let observations = request.results, !observations.isEmpty,
                  let ob = try? observations[0] else {
                      self.isFaceDetectable = true
                      return
                  }
//            print("detected")
            let fob = ob as! VNFaceObservation
            let points = fob.landmarks!
            
            //顔の中での位置を示しているので顔のbounding box 上に投影する
            let faceBox = fob.boundingBox
            let affineTransform = CGAffineTransform(translationX: faceBox.origin.x, y: faceBox.origin.y).scaledBy(x: faceBox.size.width, y: faceBox.size.height)
            
            guard var innerLips = points.innerLips?.normalizedPoints else {
                self.isFaceDetectable = true
                return
                
            }
            
            
            
            for i in 0 ..< 6 {
                let innerLipsShifted = __CGPointApplyAffineTransform(innerLips[i], affineTransform)
                innerLips[i] = innerLipsShifted
                innerLips[i].y = 1 - innerLips[i].y
            }
            
            
            let minx = innerLips.min{ a, b in a.x < b.x}
            let miny = innerLips.min{ a, b in a.y < b.y}
            let maxx = innerLips.min{ a, b in a.x > b.x}
            let maxy = innerLips.min{ a, b in a.y > b.y}
            
            let bbx : CGRect = CGRect(x: minx!.x, y: miny!.y, width: (maxx!.x - minx!.x), height: (maxy!.y - miny!.y))
            //恐らく[0][2][3][5]を平均すればいい
            //        var centerPoint = innerLips[0] + innerLips[2] + innerLips[3] + innerLips[5]
            //        centerPoint.x = centerPoint.x/4
            //        centerPoint.y = centerPoint.y/4
            //        print(innerLips)
            
            //口の範囲
//            let bbx : [CGPoint] = [innerLips[0],innerLips[2],innerLips[3],innerLips[5]]
//            let bbx : CGRect = CGRect(x: innerLips[5].x, y: innerLips[5].y, width: (innerLips[2].x - innerLips[5].x), height: (innerLips[2].y - innerLips[5].y))
//            let bbx : CGRect = CGRect(x: innerLips[0].x, y: 1-innerLips[0].y, width: (innerLips[3].x - innerLips[0].x), height: ((1-innerLips[3].y)-(1-innerLips[0].y)))
            
            //画面の向きを考慮した方がいいかも
//            let worldBoundingBox = [self.ConvertLocalToDisplay(point: bbx[0]), self.ConvertLocalToDisplay(point: bbx[1]), self.ConvertLocalToDisplay(point: bbx[2]), self.ConvertLocalToDisplay(point: bbx[3])]
            //        let x = fromMaskToBoundingBox(mask: mask)
//            print("here")
            
            guard let mask = self.mask else {
                self.isFaceDetectable = true
                return
            }
            iter : for y in Int(bbx.minY * CGFloat(mask.shape[0].intValue)) ..< Int(bbx.maxY * CGFloat(mask.shape[0].intValue)){
                for x in Int(bbx.minX * CGFloat(mask.shape[1].intValue)) ..< Int(bbx.maxX * CGFloat(mask.shape[1].intValue)){
                    if x < mask.shape[1].intValue && y < mask.shape[0].intValue{
                        mask[y * mask.shape[1].intValue + x] = 128
                    }
                }
            }
            
//            let mi = mask.image()
//            iter : for y in min(Int(worldBoundingBox[0].y), Int(worldBoundingBox[2].y))  ..< max(Int(worldBoundingBox[0].y), Int(worldBoundingBox[2].y)) {
//                for x in min(Int(worldBoundingBox[0].x), Int(worldBoundingBox[2].x)) ..< max(Int(worldBoundingBox[0].x), Int(worldBoundingBox[2].x)){
//                    if x < mask.shape[1].intValue && y < mask.shape[0].intValue{
//                        mask[y * mask.shape[1].intValue + x] = 128
//                    }
//                    //xにxついても同様に
//                    //                print("test")
//
////                    if(mask[y * mask.shape[1].intValue + x] != 0){
////                        print("eaten")
////                        break iter
////
////                    }
//
//                }
//            }
            self.mask = mask
            
            let mouthbox = bbx
            //TODO: Trackingの結果を反映していない件
//            let foodbox = self.controller.segmentator?.boundingBox!
            let foodbox = self.inputObservation?.boundingBox
//            let intersect = self.intersectBoundingBox(bb1: mouthbox, bb2: foodbox!)
            let intersect = self.intersectBoundingBox3D(mouthBox:mouthbox, foodBox: foodbox!, depthFrame: self.depth!, ob: fob)
            self.controller.boxView?.mouthBox = mouthbox
            self.controller.boxView?.foodBox = foodbox
            DispatchQueue.main.async {
                self.controller.boxView?.setNeedsDisplay()
            }
            
            
            if(intersect){
                print("INTERSECT!!!")
                self.onFoodIntersected()
            }
            
            
//            for j in 0 ..< 50 {
//                for i in 100 ..< 200 {
//                    mask[j * mask.shape[1].intValue + i] = 255
//                }
//            }
            


//            print("test")
            self.isFaceDetectable = true
        }
        
    }
    func onFoodIntersected(){
        //食べた食品のデータを記録する
//        self.totalCalorie += self.controller.currentCalorie
        self.totalCalorie += self.controller.totalFoodCalorieInstance / Float(self.controller.totalFoodCountInstance)
        self.foodCount += 1
//        let avarageCalorie = self.totalCalorie / Float(self.foodCount)
        //認識のクールタイムを設定する
//        self.controller.currentState = "cooltime"
        self.controller.isCooltime = true
        DispatchQueue.main.async {
//            let total = NSString(string: self.controller.totalCalorieLabel.text!).floatValue
//            self.controller.totalCalorieLabel.text = String(total + avarageCalorie)
            self.controller.totalCalorieLabel.text = "合計: "+String(format: "%.1f",self.totalCalorie)+"kcal"
            self.controller.totalFoodCalorieInstance = 0
            self.controller.totalFoodCountInstance = 0
            self.controller.foodCountLabel.text = String(self.foodCount)+"個食べました"
            self.controller.boxView?.fixColor = true
            self.controller.boxView?.setNeedsDisplay()
            
            Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block: {(timer) in
                print(timer)
                self.controller.isCooltime = false
                self.controller.boxView?.fixColor = false
            })
//            self.controller.currentState = "Segmentation"
        }
    }
    
    //    物体追跡についてもdounikasuru
    func startTracking(frame : CVPixelBuffer, boundingbox : CGRect){
        self.sequenceRequestHandler = VNSequenceRequestHandler()
        guard let reqestHandler = self.sequenceRequestHandler else {return}
        let inputObservation = VNDetectedObjectObservation(boundingBox: boundingbox)
        let trackingRequest = VNTrackObjectRequest(detectedObjectObservation: inputObservation, completionHandler: trackingRequestDidComplete)
        do{
            try reqestHandler.perform([trackingRequest], on: frame)
        } catch {
            print(error)
        }
    }
    func continueTracking(frame : CVPixelBuffer){
        guard let reqestHandler = self.sequenceRequestHandler else {return}
        let trackingRequest = VNTrackObjectRequest(detectedObjectObservation: self.inputObservation!, completionHandler: trackingRequestDidComplete)
        do{
            try reqestHandler.perform([trackingRequest], on: frame)
        } catch {
            print(error)
        }
    }
    
//    func intersectBoundingBox(bb1 : CGRect, bb2 : CGRect) -> Bool{
//        //3次元的にする
//        return bb1.intersects(bb2)
//    }
    func intersectBoundingBox3D(mouthBox : CGRect, foodBox : CGRect, depthFrame:CVPixelBuffer, ob:VNFaceObservation) -> Bool {
        
        guard mouthBox.intersects(foodBox) else {return false}
        //顔のdepth出す
        guard let landmarks = ob.landmarks else {return false}
        let pts : [VNFaceLandmarkRegion2D?] = [
            landmarks.leftEye,
            landmarks.rightEye,
            landmarks.nose
        ]
        let faceBox = ob.boundingBox
        var total: Float = 0
        var count = 0
        let affineTransform = CGAffineTransform(translationX: faceBox.origin.x, y: faceBox.origin.y).scaledBy(x: faceBox.size.width, y: faceBox.size.height)
        for p in pts{
//            if (p?.precisionEstimatesPerPoint![0])! < 0.1 {continue}
            let depthPoint = p!.normalizedPoints[0]
            let depthPointShifted = __CGPointApplyAffineTransform(depthPoint, affineTransform)
            CVPixelBufferLockBaseAddress(depthFrame, .readOnly)
            let rowData = CVPixelBufferGetBaseAddress(depthFrame)! + Int((1 - depthPointShifted.y)*480) * CVPixelBufferGetBytesPerRow(depthFrame)
            // swift does not have an Float16 data type. Use UInt16 instead, and then translate
            var f16Pixel = rowData.assumingMemoryBound(to: UInt16.self)[Int(depthPointShifted.x * 640)]
            CVPixelBufferUnlockBaseAddress(depthFrame, .readOnly)
            
            var f32Pixel = Float(0.0)
            var src = vImage_Buffer(data: &f16Pixel, height: 1, width: 1, rowBytes: 2)
            var dst = vImage_Buffer(data: &f32Pixel, height: 1, width: 1, rowBytes: 4)
            vImageConvert_Planar16FtoPlanarF(&src, &dst, 0)
            
            if(!f32Pixel.isNaN && f32Pixel*100 > 5){
                total += f32Pixel
                count += 1
            }
        }
        
        guard count != 0 else {return false}
        let faceDepth = total*100 / Float(count)
        //食事のdepth出す
        
        let foodDepth = self.controller.foodAverageDepth
        //交差判定する
        return abs(foodDepth - faceDepth) < 10
        
    }
    //マスクと口が重なっているのを検知
    func checkMouseIsMasked(image:CVPixelBuffer,mask:MLMultiArray, depth:CVPixelBuffer){
        DispatchQueue.global(qos: .utility).async {
//            let ci = CIImage(cvPixelBuffer: image)
            guard let request : VNRequest = self.faceLandmarkRequest else {fatalError()}
            self.depth = depth
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: image, options: [:])
            do{
                try requestHandler.perform([request])
            }catch{
                print(error)
            }
            
            self.mask = mask
        }
        self.isFaceDetectable = false
        
        //
        //        guard let observations = request.results, !observations.isEmpty, let points = try? observations[0].landmarks else {return}
        //            print("detected")
        //
        //        guard let innerLips = points.innerLips?.normalizedPoints else {return}
        //        //恐らく[0][2][3][5]を平均すればいい
        ////        var centerPoint = innerLips[0] + innerLips[2] + innerLips[3] + innerLips[5]
        ////        centerPoint.x = centerPoint.x/4
        ////        centerPoint.y = centerPoint.y/4
        ////        print(innerLips)
        //
        //        //口の範囲
        //        let bbx : [CGPoint] = [innerLips[0],innerLips[2],innerLips[3],innerLips[5]]
        //
        //        //画面の向きを考慮した方がいいかも
        //        let worldBoundingBox = [ConvertLocalToDisplay(point: bbx[0]), ConvertLocalToDisplay(point: bbx[1]), ConvertLocalToDisplay(point: bbx[2]), ConvertLocalToDisplay(point: bbx[3])]
        ////        let x = fromMaskToBoundingBox(mask: mask)
        //        print("here")
        //
        //
        //
        //        for y in min(Int(worldBoundingBox[0].y), Int(worldBoundingBox[2].y))  ..< max(Int(worldBoundingBox[0].y), Int(worldBoundingBox[2].y)) {
        //            for x in min(Int(worldBoundingBox[0].x), Int(worldBoundingBox[2].x)) ..< max(Int(worldBoundingBox[0].x), Int(worldBoundingBox[2].x)){
        //            //xにxついても同様に
        ////                print("test")
        //                if(mask[y * mask.shape[0].intValue + x] != 0){
        //                    print("eaten")
        //                }
        //
        //            }
        //        }
        //        for y in boundingbox[0].x ..< boundingbox[1].x {
        //
        //        }
        
        //        innerLips.
        //        口の中心座標を計算する
        //        let centerPointOfInnnerlips =
        
        //        口の周辺座標半径を計算する
        //        半径内に食事マスクが重ならないか計算する
        //        食事マスクが存在する場合、深度が基準値以内にあるかを調べる
        //        球形の方が正しそうだけど実装を考慮すると直方体でも問題なさそう
        
        
        return
    }
    
    func ConvertLocalToDisplay(point:CGPoint) -> CGPoint{
        return CGPoint(x: point.x * 640, y: (1 - point.y) * 480)
    }
    
    //    static func fromMaskToBoundingBox(mask:MLMultiArray)->Array<Any>{
    //
    //        //最初の行、最初の列、最後の行、最後の列を組み合わせれば取れる
    //
    //
    //        let width = mask.shape[1]
    //        let height = mask.shape[0]
    //        for y in 0 ..< height.intValue{
    //            for x in 0 ..< width.intValue {
    //                let i = mask[y * width.intValue + x]
    //                if i != 0 {
    //                    print("mask!")
    //                }
    //                print(i)
    //            }
    //        }
    //        return [0]
    //    }
    
    
}
extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
//    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
//        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
//    }
//
//    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
//        CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
//    }
//
//    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
//        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
//    }
}
