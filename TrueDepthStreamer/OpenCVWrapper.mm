// OpenCVTest.mm

#import "opencv2/opencv.hpp"
#import "opencv2/imgproc.hpp"
#import "opencv2/imgcodecs.hpp"
#import "opencv2/imgcodecs/ios.h"

#import "OpenCVWrapper.h"

@implementation OpenCVWrapper

+ (nullable CGImageRef)recompile:(CGImageRef _Nullable)src
{
    cv::Mat srcImageMat;
    CGImageToMat(src, srcImageMat);
    return MatToCGImage(srcImageMat);
}

+ (nullable UIImage *)filteredImage:(CGImageRef _Nullable )src
{
    UIImage *srcImage = [UIImage imageNamed:@"screenshot.png"];
    cv::Mat srcImageMat;
    cv::Mat dstImageMat;
    

    // UIImageからcv::Matに変換
    CGImageToMat(src, srcImageMat);

    // 色空間をRGBからGrayに変換
    cv::cvtColor(srcImageMat, dstImageMat, cv::COLOR_RGB2GRAY);

    // cv::MatをUIImageに変換
    UIImage *dstImage = MatToUIImage(dstImageMat);


    return dstImage;
}
+ (nullable CGImageRef)binarize:(CGImageRef _Nullable )src :(CGPoint)threshold_point
{
    cv::Mat srcImageMat;
    cv::Mat grayMat;
    cv::Mat underMat;
    cv::Mat overMat;
    cv::Mat dstImageMat;
    
    CGImageToMat(src, srcImageMat);
    UIImage *d1 = MatToUIImage(srcImageMat);
    cv::cvtColor(srcImageMat, grayMat, cv::COLOR_RGB2GRAY);
    UIImage *d2 = MatToUIImage(grayMat);
    
    float threshold = grayMat.data[(int)threshold_point.y * grayMat.cols + (int)threshold_point.x];
    
    cv::threshold(grayMat, dstImageMat, threshold+10, 255, cv::THRESH_BINARY_INV);
//    cv::threshold(dstImageMat, overMat, threshold+10, 255, cv::THRESH_BINARY_INV);
//    cv::bitwise_and(underMat, overMat, dstImageMat);
    
    CGImageRef dst = MatToCGImage(dstImageMat);
    
//    print(grayMat.at<cv::Vec>(<#int i0#>, <#int i1#>))
    UIImage *d3 = MatToUIImage(dstImageMat);
    
    return dst;
}
+ (nullable CGImageRef)masking:(CGImageRef _Nullable )input :(CGImageRef _Nullable)mask
{
    
    cv::Mat inputMat;
    cv::Mat maskMat;
    cv::Mat dstMat;
    
    CGImageToMat(input, inputMat);
    CGImageToMat(mask, maskMat);
    
    inputMat.copyTo(dstMat,maskMat);
    
    UIImage *d = MatToUIImage(inputMat);
    UIImage *d2 = MatToUIImage(maskMat);
    UIImage *d3 = MatToUIImage(dstMat);
    
    return MatToCGImage(dstMat);
    
}

+ (nullable CGImageRef)preproc:(CGImageRef _Nullable)src
{
    cv::Mat srcImageMat;
    CGImageToMat(src, srcImageMat);
    
    cv::Mat dstImageMat;
    
    dstImageMat = 2 * (srcImageMat/255) - 1;
    //mean,std
//    float mean = 0.5;
//    float std = 0.5;
//
//    for (int i = 0; i < 3; i++) {
////        dstImageMat
//    }
    
    return MatToCGImage(dstImageMat);
}

+ (int)countPixel:(CGImageRef _Nullable)src
{
    cv::Mat srcImageMat;
    CGImageToMat(src, srcImageMat);
//    cv::Mat dstImageMat;
//    int threshold = 127;
//    cv::threshold(srcImageMat, dstImageMat, threshold, 0, 255);
//    UIImage *d = MatToUIImage(dstImageMat);
//    UIImage *d2 = MatToUIImage(srcImageMat);
    return cv::countNonZero(srcImageMat);
    
}

+ (nullable NSArray *)aveDepth:(CGImageRef _Nullable)depth :(CGImageRef _Nullable)mask
{
    NSArray *ret;
    int count = [self countPixel:mask];
    if (count == 0) {
        return nil;
    }
    cv::Mat depthImageMat;
    CGImageToMat(depth, depthImageMat);
    cv::Mat maskImageMat;
    CGImageToMat(mask, maskImageMat);
    
    cv::Mat maskedDepthMat;
    cv::copyTo(depthImageMat, maskedDepthMat, maskImageMat);
        UIImage *d = MatToUIImage(maskedDepthMat);
    
    cv::Scalar total_pixel = cv::sum(maskedDepthMat);
    cv::Scalar divs;
    
    divs = total_pixel / count;
    
    ret = [[NSArray alloc] initWithObjects:
           [NSNumber numberWithFloat:divs[0]],
           [NSNumber numberWithFloat:divs[1]],
           [NSNumber numberWithFloat:divs[2]],
           nil];
    
    return ret;
}

//+ (nullable CGImage *)filteredImage
//{
//    UIImage *srcImage = [UIImage imageNamed:@"screenshot.png"];
//    cv::Mat srcImageMat;
//    cv::Mat dstImageMat;
//
//    // UIImageからcv::Matに変換
//    UIImageToMat(srcImage, srcImageMat);
//
//    // 色空間をRGBからGrayに変換
//    cv::cvtColor(srcImageMat, dstImageMat, cv::COLOR_RGB2GRAY);
//
//    // cv::MatをUIImageに変換
//    CGImage *dstImage = MatToCGImage(dstImageMat);
//
//
//    return dstImage;
//}

@end
