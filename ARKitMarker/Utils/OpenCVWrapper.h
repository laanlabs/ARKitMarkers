//
//  OpenCVWrapper.h
//
//  Created by cc on 6/26/17.
//  Copyright © 2017 Laan Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <simd/types.h>


#import <SceneKit/SceneKit.h>



typedef struct PoseResults2 {
    
    float translation_vector[3];
    float euler_angles[3];
    
} PoseResults2;

typedef struct MarkerPose {
    bool found;
    SCNVector3 tvec;
    SCNVector3 rvec;
    SCNMatrix4 rotMat;
    int id;
} MarkerPose;



@interface UIImage(CVUtils)

+(UIImage*)imageWithBuffer:(uint8_t*)buffer size:(int)numBytes w:(int)w h:(int)h isGray:(bool)isGray;

@end


@interface OpenCVWrapper : NSObject


+(MarkerPose) findMarkers:(CVPixelBufferRef) pixelBuffer
                       fx:(float)fx fy:(float)fy ox:(float)ox oy:(float)oy
       markerLengthMeters:(float)markerLength
          imageDownsample:(float)scale;




@end

