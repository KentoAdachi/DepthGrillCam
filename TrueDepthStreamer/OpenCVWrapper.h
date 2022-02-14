// OpenCVTest.h


//#import "opencv2/opencv.hpp"
//#import "opencv2/imgproc.hpp"
//#import "opencv2/imgcodecs.hpp"
//#import "opencv2/imgcodecs/ios.h"
#import <UIKit/UIKit.h>

@interface OpenCVWrapper : NSObject

+ (nullable CGImageRef)recompile:(CGImageRef _Nullable)src;
+ (nullable UIImage *)filteredImage:(CGImageRef _Nullable)src;
+ (nullable CGImageRef)binarize:(CGImageRef _Nullable )src:(CGPoint)threshold_point;
+ (nullable CGImageRef)masking:(CGImageRef _Nullable )input:(CGImageRef _Nullable)mask;
+ (nullable CGImageRef)preproc:(CGImageRef _Nullable)src;
+ (int)countPixel:(CGImageRef _Nullable)src;
+ (nullable NSArray *)aveDepth:(CGImageRef _Nullable)depth :(CGImageRef _Nullable)mask;

@end
