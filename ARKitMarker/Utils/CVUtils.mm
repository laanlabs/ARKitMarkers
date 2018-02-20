//
//  CVUtils.m

#import <Foundation/Foundation.h>


#import <Accelerate/Accelerate.h>
#import "CVUtils.h"

#define TICK   NSDate *startTime = [NSDate date]
#define TOCK   NSLog(@"Time: %5.3f ms", -[startTime timeIntervalSinceNow] * 1000)

//#define TOCK   NSLog(@"%s Time: %f", __PRETTY_FUNCTION__ , -[startTime timeIntervalSinceNow])


@implementation UIImage(OpenCV)

- (cv::Mat)cvMat
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(self.CGImage);
    CGFloat cols = self.size.width;
    CGFloat rows = self.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), self.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

- (cv::Mat)cvMatGray
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(self.CGImage);
    CGFloat cols = self.size.width;
    CGFloat rows = self.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), self.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

+(UIImage*)imageWithCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    CGBitmapInfo bitmapInfo;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
        bitmapInfo = kCGImageAlphaNone|kCGBitmapByteOrderDefault;
    } else if ( cvMat.elemSize() == 3) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        bitmapInfo = kCGImageAlphaNone|kCGBitmapByteOrderDefault;
    } else if ( cvMat.elemSize() == 4 ) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        bitmapInfo = kCGImageAlphaLast|kCGBitmapByteOrderDefault;
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        bitmapInfo,// bitmap info
                                        //kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
    
}

@end




cv::Mat cvMatWithCVImageBuffer(CVImageBufferRef imageBuffer)
{
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    void* bufferAddress;
    size_t width;
    size_t height;
    size_t bytesPerRow;
    
    int format_opencv;
    
    OSType format = CVPixelBufferGetPixelFormatType(imageBuffer);
    if (format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        
        format_opencv = CV_8UC1;
        
        bufferAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        width = CVPixelBufferGetWidthOfPlane(imageBuffer, 0);
        height = CVPixelBufferGetHeightOfPlane(imageBuffer, 0);
        bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
        
    } else { // expect kCVPixelFormatType_32BGRA
        
        format_opencv = CV_8UC4;
        
        bufferAddress = CVPixelBufferGetBaseAddress(imageBuffer);
        width = CVPixelBufferGetWidth(imageBuffer);
        height = CVPixelBufferGetHeight(imageBuffer);
        bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        
    }
    
    cv::Mat image((int)height, (int)width, format_opencv, bufferAddress, bytesPerRow);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    return  image;
}


cv::Mat get_downsampled_cv_mat(CVImageBufferRef imageBuffer,
                               vImage_Buffer  * dest_buffer,
                               int out_max_dim)
{
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    
    size_t width;
    size_t height;
    size_t bytesPerRow;
    
    int ds_width, ds_height;
    
    int out_width, out_height;
    
    int format_opencv;
    
    OSType format = CVPixelBufferGetPixelFormatType(imageBuffer);
    
    assert(format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange);
    
    width = CVPixelBufferGetWidthOfPlane(imageBuffer, 0);
    height = CVPixelBufferGetHeightOfPlane(imageBuffer, 0);
    
    bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
    
    ds_width = out_max_dim;
    ds_height = height * (ds_width / (float)width);
    
    // no rotation for now
    out_width = ds_width;
    out_height = ds_height;
    
    void *srcBuff = CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);
    
    vImage_Buffer src = { srcBuff, height, width, bytesPerRow};
    
    if ( dest_buffer->data == NULL || dest_buffer->width != out_width || dest_buffer->height != out_height ) {
        
        NSLog(@"Allocating downsampled gray dest buffer %i x %i ", out_width , out_height);
        
        // This doesn't set dest_buffer->rowBytes, which causes the rotation to fail
        // and was killing me...
        vImageBuffer_Init(dest_buffer, out_height, out_width, 8, kvImageNoFlags);
        
        //unsigned char *destData = (unsigned char*)calloc(out_width * out_height, sizeof(unsigned char));
        //dest_buffer->data = destData;
        dest_buffer->width = out_width;
        dest_buffer->height = out_height;
        dest_buffer->rowBytes = out_width;
        
    }
    
    //vImage_Error err = vImageScale_ARGB8888(&src, temp_buffer, NULL, kvImageNoFlags);
    vImage_Error err = vImageScale_Planar8(&src, dest_buffer, NULL, kvImageNoFlags);
    if (err != kvImageNoError) NSLog(@"%ld", err);
    
    format_opencv = CV_8U;
    
    cv::Mat image((int)out_height, (int)out_width, format_opencv, dest_buffer->data, dest_buffer->rowBytes );
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    return image;
    
}




cv::Mat get_downsampled_cv_mat(void * srcBuff,
                               int width,
                               int height,
                               vImage_Buffer  * dest_buffer,
                               int out_max_dim)
{
    
    //size_t width;
    //size_t height;
    size_t bytesPerRow = width;
    
    int ds_width, ds_height;
    int out_width, out_height;
    
    int format_opencv;
    
    ds_width = out_max_dim;
    ds_height = height * (ds_width / (float)width);
    
    // no rotation for now
    out_width = ds_width;
    out_height = ds_height;
    
    //void *srcBuff = CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);
    
    vImage_Buffer src = { srcBuff, static_cast<vImagePixelCount>(height), static_cast<vImagePixelCount>(width), bytesPerRow};
    
    if ( dest_buffer->data == NULL || dest_buffer->width != out_width || dest_buffer->height != out_height ) {
        
        NSLog(@"Allocating downsampled gray dest buffer %i x %i ", out_width , out_height);
        
        // This doesn't set dest_buffer->rowBytes, which causes the rotation to fail
        // and was killing me...
        vImageBuffer_Init(dest_buffer, out_height, out_width, 8, kvImageNoFlags);
        
        //unsigned char *destData = (unsigned char*)calloc(out_width * out_height, sizeof(unsigned char));
        //dest_buffer->data = destData;
        dest_buffer->width = out_width;
        dest_buffer->height = out_height;
        dest_buffer->rowBytes = out_width;
        
    }
    
    vImage_Error err = vImageScale_Planar8(&src, dest_buffer, NULL, kvImageNoFlags);
    if (err != kvImageNoError) NSLog(@"%ld", err);
    
    format_opencv = CV_8U;
    
    cv::Mat image((int)out_height, (int)out_width, format_opencv, dest_buffer->data, dest_buffer->rowBytes );
    
    return image;
    
}



