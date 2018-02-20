//
//  CVUtils.h
//  ARMeasure
//



#import <UIKit/UIKit.h>
#import <Accelerate/Accelerate.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

#include "opencv2/core/core.hpp"

@interface UIImage(OpenCV)

- (cv::Mat)cvMat;
- (cv::Mat)cvMatGray;

+(UIImage*)imageWithCVMat:(cv::Mat)cvMat;

@end

cv::Mat cvMatWithCVImageBuffer(CVImageBufferRef imageBuffer);


cv::Mat get_downsampled_cv_mat(CVImageBufferRef imageBuffer,
                               vImage_Buffer  * dest_buffer,
                               int out_max_dim);

cv::Mat get_downsampled_cv_mat(void * srcBuff,
                               int width,
                               int height,
                               vImage_Buffer  * dest_buffer,
                               int out_max_dim);
