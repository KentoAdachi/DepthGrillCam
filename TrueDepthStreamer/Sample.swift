
//import ReplayKit

final class Sample {
    let timingInfo: CMSampleTimingInfo

    init(sampleBuffer: CMSampleBuffer) {
        let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)
        let decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
        timingInfo = CMSampleTimingInfo(duration: duration, presentationTimeStamp: presentationTimeStamp, decodeTimeStamp: decodeTimeStamp)
    }
    
    func generateCMSampleBuffer(from cvPixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        var timimgInfo: CMSampleTimingInfo = timingInfo
        var videoInfo: CMVideoFormatDescription!
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: cvPixelBuffer, formatDescriptionOut: &videoInfo)
        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                           imageBuffer: cvPixelBuffer,
                                           dataReady: true,
                                           makeDataReadyCallback: nil,
                                           refcon: nil,
                                           formatDescription: videoInfo,
                                           sampleTiming: &timimgInfo,
                                           sampleBufferOut: &sampleBuffer)

        return sampleBuffer
    }
}
