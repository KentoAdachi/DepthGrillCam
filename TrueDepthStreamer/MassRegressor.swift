import Foundation
import CoreML

class MassRegressor{
//    let MassRegressionModel : MLModel
    init() {
//        self.MassRegressionModel = massRegressionModel
        
    }
    
    func predict(depth : CGImage,mask : CGImage)->Float{
        let numPixels = OpenCVWrapper.countPixel(mask)
        let aved = OpenCVWrapper.aveDepth(depth,mask)
        
        return Float(numPixels)
    }
    func count_pixel(mask:CGImage) -> Int32{
        return OpenCVWrapper.countPixel(mask)
    }
    func ave_depth(depth : CGImage,mask :CGImage) -> NSArray?{
        return OpenCVWrapper.aveDepth(depth,mask) as? NSArray
    }
    
    func predict_dummy(depth : CGImage,mask :CGImage)->Float{
//        let numPixels = OpenCVWrapper.countPixel(mask)
//        let aved = OpenCVWrapper.aveDepth(depth,mask)
        return Float.random(in: 280..<300)
        
    }
    
    
    
    func predict(weight:Int,depth:[Float]) -> Float {
        return 0
    }
}

