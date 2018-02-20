//
//  OpenCVWrapper.m
//
//  Created by cc on 6/26/17.
//  Copyright © 2017 Laan Labs. All rights reserved.
//

#import <opencv2/core.hpp>
#include <opencv2/calib3d/calib3d.hpp>
#include <opencv2/aruco.hpp>

#import "OpenCVWrapper.h"
#include "CVUtils.h"


using namespace std;
using namespace cv;


@implementation OpenCVWrapper

static vImage_Buffer dest_buffer = {NULL, 0, 0, 0};



+(MarkerPose) findMarkers:(CVPixelBufferRef) pixelBuffer
                       fx:(float)fx fy:(float)fy ox:(float)ox oy:(float)oy
       markerLengthMeters:(float)markerLength
          imageDownsample:(float)scale {
    
    MarkerPose result;
    result.found = false;
    
    // 3 seems OK
    //float scale = 3.2; // 1.6 would be nice = 800
    //float scale = 2.5;
    
    Mat image;
    
    if ( scale != 1.0 ) {
        int out_width = 1280 / scale;
        image = get_downsampled_cv_mat(pixelBuffer, &dest_buffer, out_width);
    } else {
        image = cvMatWithCVImageBuffer(pixelBuffer);
    }
    
    //Mat imageCopy;
    
    ///image.copyTo(imageCopy);
    
    //cv::cvtColor(imageCopy, imageCopy, CV_GRAY2RGB);
    
    
    Ptr<aruco::DetectorParameters> detectorParams = aruco::DetectorParameters::create();
    
    
    detectorParams->cornerRefinementMethod = aruco::CORNER_REFINE_SUBPIX; // do corner refinement in markers
    //detectorParams->cornerRefinementMaxIterations = 20;
    
    
    /*detectorParams->adaptiveThreshWinSizeMin = 13;
    detectorParams->adaptiveThreshWinSizeStep = 1;
    detectorParams->adaptiveThreshWinSizeMax = 13;
    */
    
    //detectorParams->polygonalApproxAccuracyRate = 0.1;
    //detectorParams->maxErroneousBitsInBorderRate = 0.5;
    
    
    // 1280 * 0.1 = 128 px
    // dont do much for perf
    //detectorParams->minMarkerPerimeterRate = 0.25;
    
    /*
     dictionary: DICT_4X4_50=0, DICT_4X4_100=1, DICT_4X4_250=2,"
     "DICT_4X4_1000=3, DICT_5X5_50=4, DICT_5X5_100=5, DICT_5X5_250=6, DICT_5X5_1000=7, "
     "DICT_6X6_50=8, DICT_6X6_100=9, DICT_6X6_250=10, DICT_6X6_1000=11, DICT_7X7_50=12,"
     "DICT_7X7_100=13, DICT_7X7_250=14, DICT_7X7_1000=15, DICT_ARUCO_ORIGINAL = 16}"
     */
    
    int dictionaryId = 16; // 16 works
    
    Ptr<aruco::Dictionary> dictionary = aruco::getPredefinedDictionary(aruco::PREDEFINED_DICTIONARY_NAME(dictionaryId));
    

    cv::Mat projectionMat = cv::Mat::zeros(3,3, CV_64F);
    
    cv::Matx33f camMatrix = projectionMat;//cv::Matx33f(3,3);
    
    //float focalLength = 100.0;
    
    camMatrix(0,0) = fx / scale;
    camMatrix(1,1) = fy / scale;
    camMatrix(0,2) = ox / scale;
    camMatrix(1,2) = oy / scale;
    camMatrix(2,2) = 1;
    
    vector< int > ids;
    vector< vector< Point2f > > corners, rejected;
    vector< Vec3d > rvecs, tvecs;
    
    // detect markers and estimate pose
    aruco::detectMarkers(image, dictionary, corners, ids, detectorParams, rejected);
    
    bool estimatePose = true;
    
    if(estimatePose && ids.size() > 0) {
        
        aruco::estimatePoseSingleMarkers(corners, markerLength, camMatrix, cv::noArray(), rvecs, tvecs);
        
    }
    
    if(ids.size() > 0) {
        
        //aruco::drawDetectedMarkers(imageCopy, corners, ids);
        
        if(estimatePose) {
            
            for(unsigned int i = 0; i < ids.size(); i++) {
                
                //NSLog(@" marker: %i ", ids[i]);
                
                //if ( ids[i] == 123 || ids[i] == 456 || ids[i] == 333 || ids[i] == 444 ) {
                if ( true ) {
                    
                    result.found = true;
                    
                    result.tvec = SCNVector3Make(tvecs[i][0], tvecs[i][1], tvecs[i][2]);
                    result.rvec = SCNVector3Make(rvecs[i][0], rvecs[i][1], rvecs[i][2]);
                    
                    Mat expandedR;
                    
                    Rodrigues(rvecs[i], expandedR);
                    
                    result.rotMat = SCNMatrix4Identity;
                    
                    result.id = ids[i];
                    
                    // x and y swapped, z
                    // col 1
                    result.rotMat.m11 = -expandedR.at<double>(1,0);
                    result.rotMat.m12 = -expandedR.at<double>(0,0);
                    result.rotMat.m13 = -expandedR.at<double>(2,0);
                    
                    // col 2
                    result.rotMat.m21 = -expandedR.at<double>(1,1);
                    result.rotMat.m22 = -expandedR.at<double>(0,1);
                    result.rotMat.m23 = -expandedR.at<double>(2,1);
                    
                    // col 3
                    result.rotMat.m31 = -expandedR.at<double>(1,2);
                    result.rotMat.m32 = -expandedR.at<double>(0,2);
                    result.rotMat.m33 = -expandedR.at<double>(2,2);
                    
                    assert(expandedR.type() == CV_64F);
                    
                    return result;
                    
                    //expandedR.type() == CV_64F
                    //std::cout << expandedR << std::endl;
                    
                    //aruco::drawAxis(imageCopy, camMatrix, cv::noArray(), rvecs[i], tvecs[i], markerLength * 0.5f);
                }
            }
        }
    }
    

    return result;
    
}


@end
