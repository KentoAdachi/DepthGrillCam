//
//  DrawView.swift
//  TrueDepthStreamer
//
//  Created by Kento Adachi on 2022/01/04.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation
import UIKit

class BoxView: UIView {
    
    var foodBox : CGRect?
    var mouthBox : CGRect?
    var fixColor : Bool = false
    
    private func convertToScreenCord(rect : CGRect)->CGRect{
        //TODO: 物体追跡の追従後の座標が上下逆になっているので修正する
        //TODO: 決め打ち系の座標直す
        //boxview位置合わせ座標の原点x = screen.width/2 - metalviewのtransformRect.width/2
        //正規化された値が入力されている
        let x = rect.minY
        let y = rect.minX
        let width = rect.height
        let height = rect.width
        // PreviewMetalView内のcgrectを参照すれば良い（ただしprivate）
        let screenWidth : CGFloat = 375
        let screenHeight : CGFloat = 500
//        let screenWidth : CGFloat = 420
//        let screenHeight : CGFloat = 560
        
//        let rect = CGRect(x: x * w, y: y * h + 180, width: width * w, height: height * h)
//        let affine = CGAffineTransform(rotationAngle: -.pi/2)
//        let rect =  CGRect(x: x * w, y: y * h + 180, width: width * w, height: height * h)

        let rect = CGRect(x: 710-(y * screenHeight), y: x * screenWidth+10, width: -height * screenHeight, height: width * screenWidth)
        let affine = CGAffineTransform(scaleX: 1, y: 1)
        return rect.applying(affine)
    }
    
    func setFixColor(flag : Bool){
        self.fixColor = flag
    }
    
    override func draw(_ rect: CGRect) {
        
        UIColor.green.setStroke()
        if self.fixColor {
            UIColor.purple.setStroke()
        }
        if let f = self.foodBox {
//            let f2 = CGRect(x: f.minY, y: f.minX, width: f.height, height: f.width)
//            let f2 = f
            let foodpath = UIBezierPath(rect: self.convertToScreenCord(rect: f))
            foodpath.lineWidth = 3
            foodpath.stroke()
        }
        UIColor.red.setStroke()
        if self.fixColor {
            UIColor.purple.setStroke()
        }
        if let m = self.mouthBox{
            let mouthpath = UIBezierPath(rect: self.convertToScreenCord(rect: m))
            mouthpath.lineWidth = 3
            mouthpath.stroke()
        }
        UIColor.white.setStroke()
        if self.fixColor {
            UIColor.purple.setStroke()
        }
        let rec = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
        UIBezierPath(rect: self.convertToScreenCord(rect: rec)).stroke()
    }
}
