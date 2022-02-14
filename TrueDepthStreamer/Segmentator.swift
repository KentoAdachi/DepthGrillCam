//
//  Segmentator.swift
//  TrueDepthStreamer
//
//  Created by Kento Adachi on 2021/08/15.
//  Copyright © 2021 Apple. All rights reserved.
//

import Foundation

import Vision


@available(iOS 14.0, *)
class Segmentator {
    
    //inputがmlmultiarrayでimageじゃないからvncoremlmldelを作成できないっぽい
    //DGDSegModelMultilabel9_with_metadata
    var imageSegmentationModel: DGDSegModelMultilabel_aug_half4_with_metadata?
    var request : VNCoreMLRequest?
    var maskImage : CGImage?
    var maskImageUI: UIImage?
    var superView : UIView
//    var superController : CameraViewController
    var resultView : UIImageView?
    var viewController : CameraViewController
    var isSegmentable : Bool = true
    var isFoodDetected : Bool = false
    var boundingBox: CGRect? = nil
    var segmap: MLMultiArray?
    var category : Int = 0
    var pixelcount : Int = 0
//    var controller : CameraViewController
    
    
    //    var inputImage : CGImage?
    
    
    init(cameraViewController : CameraViewController) {
        self.superView = cameraViewController.view
        self.viewController =  cameraViewController
        do {
            try imageSegmentationModel = DGDSegModelMultilabel_aug_half4_with_metadata()
        } catch let error as NSError {
            print(error)
        }
        setupModel()
    }
    
    func getMask()->CGImage?{
        return self.maskImage
    }
    func getMask()->MLMultiArray?{
        return self.segmap
    }
    
    private func setupModel(){
        let visionModel = try? VNCoreMLModel(for: imageSegmentationModel!.model )
        
        request = VNCoreMLRequest(model: visionModel!, completionHandler: visionRequestDidComplete)
        request?.preferBackgroundProcessing = true
        request?.imageCropAndScaleOption = .scaleFill
        
    }
    func predict(originalImage:CGImage) {
        //        OpenCVWrapper.preproc(originalImage)
        DispatchQueue.global(qos: .userInitiated).async {
            guard let request = self.request else { fatalError() }
            let handler = VNImageRequestHandler(cgImage: originalImage, options: [:])
            //                self.inputImage = originalImage
            do {
                try handler.perform([request])
            }catch {
                print(error)
            }
        }
        self.isSegmentable = false
    }
    
    func convertMLArrayToArray(multiarray: MLMultiArray) -> Array<Float>?{
        guard let b = try? UnsafeBufferPointer<Float>(multiarray) else {
            return nil
        }
        let ret = Array(b)
        return ret
    }
    
    func findBoundingBox(xw:MLMultiArray,yw:MLMultiArray) ->CGRect {
        //TODO: 0~1の値にスケーリングする
        var x1 = 9999
        var x2 = 0
        var y1 = 9999
        var y2 = 0
        for i in 0 ..< Int(truncating: xw.shape[0]) {
            if xw[i] == 0 {continue}
            if x1 > Int(truncating: xw[i]) {
                x1 = Int(truncating: xw[i])
            }
            if x2 < Int(truncating: xw[i]) {
                x2 = Int(truncating: xw[i])
            }
        }
        for i in 0 ..< Int(truncating: yw.shape[0]) {
            if yw[i] == 0 {continue}
            if y1 > Int(truncating: yw[i]) {
                y1 = Int(truncating: yw[i])
            }
            if y2 < Int(truncating: yw[i]) {
                y2 = Int(truncating: yw[i])
            }
        }
        
        //scaling
        let xf : Double = Double(x1) / 640
        let yf : Double = Double(y1) / 480
        let w : Double = Double(x2-x1) / 640
        let h : Double = (Double(y2-y1) / 480)
        
        
        
        
        return CGRect(x: xf, y: yf, width: w, height: h)
    }
    
    
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        //TODO: model output purserみたいなものを実装
        //TODO: 検出されたバウンディングボックスの大きさが小さい場合の例外処理
        DispatchQueue.global(qos: .userInitiated).async {
            self.isSegmentable = true
            
            guard let observations = request.results as? [VNCoreMLFeatureValueObservation] else {
                print("cannot convert observations to FeatureValueObservation")
                return
            }
            //observationsの順番が制御できないので決め打ちする必要がある
            //しかもモデルによって出力の順番が違う。どうにかならんのかこれ
            //half1
            guard let segmentationmap = observations[2].featureValue.multiArrayValue else {return}
            
            //half1
//            let pixel_count = observations[0].featureValue.multiArrayValue![0] as NSNumber
            //half2
            //half4
            let pixel_count = observations[3].featureValue.multiArrayValue![0] as NSNumber
            
//            let pixel_count = observations[4].featureValue.multiArrayValue![0] as NSNumber
            guard pixel_count as! Int > 0 else {
                self.isFoodDetected = false
                return
            }
            //half1
//            let yw = observations[1].featureValue.multiArrayValue
            //half2
            
//            let yw = observations[1].featureValue.multiArrayValue
            //half4
            let yw = observations[0].featureValue.multiArrayValue
            //half1
//            let xw = observations[3].featureValue.multiArrayValue
            //half2
            
//            let xw = observations[0].featureValue.multiArrayValue
            //half4
            let xw = observations[1].featureValue.multiArrayValue
//            let xw = observations[0].featureValue.multiArrayValue
            let bb = self.findBoundingBox(xw: xw!, yw: yw!)
            //bbを左右反転する
            //half1
            //half2
            //half4
            let category = observations[4].featureValue.multiArrayValue![0]
//            let category = observations[3].featureValue.multiArrayValue![0]
            self.category = Int(category)
            self.pixelcount = Int(pixel_count)
            
            self.isFoodDetected = true
            self.boundingBox = bb
            
//            print(observations[0].featureValue.multiArrayValue)
//            print(observations[2].featureValue.multiArrayValue)
//            print(observations[3].featureValue.multiArrayValue)
            
//            if observations[3].featureValue.int64Value != 0 {
//                print("here")
//            }
            self.segmap = segmentationmap
//            self.viewController.currentState = "estimation"
            self.viewController.setCurrentState(state: "estimation")
            let uii :UIImage = segmentationmap.image(min: 0, max: 5)!
            let cgi : CGImage = uii.cgImage!
            //                        let cat = OpenCVWrapper.masking(self.inputImage, cgi)
            DispatchQueue.main.async {
//                self.maskImageUI = uii
//                self.maskImage = cgi
//                if let resv = self.resultView {
//                    resv.image = uii
//                } else {
//                    self.resultView = UIImageView(image: uii)
//                    //                                self.resultView?.transform = CGAffineTransform(rotationAngle: -CGFloat(M_PI)/2)
//                    self.resultView?.transform = (self.resultView?.transform.rotated(by: -CGFloat(M_PI)/2))!
//                    self.resultView?.transform = self.resultView!.transform.scaledBy(x: -0.35, y: 0.35)
//
//
//                    self.superView.addSubview(self.resultView!)
//
//                }
                // ここを呼ぶとマスクが出る
//                self.updateResultView(maskImage: uii)
            }
            self.viewController.eatingActionRecognizer?.isFoodTracking = false
            
//            let mask = segmentationmap.getElement(a: 0, b: 0, c: 0)
            
            //                        print("Success")
            //                        self.imageView.image = image
            
            //                print("here")
            
            //                    self.startSegmentationButton.setTitle("Done", for: .normal)
            
        }
        
    }
    
    func updateResultView(maskImage : UIImage){
//        self.maskImageUI = uii
//        self.maskImage = cgi
        if let resv = self.resultView {
            resv.image = maskImage
        } else {
            self.resultView = UIImageView(image: maskImage)
            //                                self.resultView?.transform = CGAffineTransform(rotationAngle: -CGFloat(M_PI)/2)
//            self.resultView?.transform = (self.resultView?.transform.rotated(by: -CGFloat(M_PI)/2))!
            self.resultView?.transform = self.resultView!.transform.scaledBy(x: -0.35, y: 0.35)
            
            self.resultView?.isUserInteractionEnabled = false
            
            self.superView.addSubview(self.resultView!)
            
        }
    }
    
    //画像を入力する
    //マスク画像を返す
    //モデルのセットアップ
    //モデルの実行
    //mlmultiarray -> uiimage
    
}

extension MLMultiArray{
    func getElement(a : Int, b : Int, c : Int) -> NSNumber{
        var linearIndex = 0
        linearIndex += a * self.strides[1].intValue
        linearIndex += b * self.strides[2].intValue
        linearIndex += c * self.strides[3].intValue
        return self[linearIndex]
    }
//    func getWidth()->NSNumber{
//        return self.strides[1]
//    }
//    func getHeight()->NSNumber{
//        return self.strides[2]
//    }
}
