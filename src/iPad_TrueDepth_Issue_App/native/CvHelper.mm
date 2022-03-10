//
//  CvHelper.m
//  iPad_TrueDepth_Issue_App
//
//  Created by Thomas Lindemeier on 2022.
//

#import <opencv2/opencv.hpp>
#include <opencv2/videoio/registry.hpp>

#define OPENCV_VIDEOIO_DEBUG 1
#import "CvHelper.h"

@implementation CvHelper

+(void) writeDepthPng: (NSString *) filePath withData:(AVDepthData *) data {
    CVPixelBufferRef pixelBuffer = data.depthDataMap;
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    int width = (int) CVPixelBufferGetWidth(pixelBuffer);
    int height = (int) CVPixelBufferGetHeight(pixelBuffer);
    uint8_t *baseAddress = (uint8_t *) CVPixelBufferGetBaseAddress(pixelBuffer);
    cv::Mat result(height, width, CV_32F, baseAddress), matImg;

    cv::Mat result16u;
    float multiple = 10000;
    result *= multiple;
    result.convertTo(result16u, CV_16U);
    cv::InputArray img = cv::InputArray(result16u);

    cv::imwrite([filePath UTF8String], img);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

+(void) writeRgb: (NSString *) filePath withFrame:(ARFrame *) frame {
//    NSLog(@"@", cv::videoio_registry::getBackends())

    CVPixelBufferRef buffer = frame.capturedImage;
    cv::Mat mat;
    //Lock the base Address so it doesn't get changed!
    CVPixelBufferLockBaseAddress(buffer, 0);
    //Get the data from the first plane (Y)
    void *address =  CVPixelBufferGetBaseAddressOfPlane(buffer, 0);
    int bufferWidth = (int)CVPixelBufferGetWidthOfPlane(buffer,0);
    int bufferHeight = (int)CVPixelBufferGetHeightOfPlane(buffer, 0);
    //Get the pixel format
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(buffer);

    cv::Mat converted;
    //NOTE: CV_8UC3 means unsigned (0-255) 8 bits per pixel, with 3 channels!
    //Check to see if this is the correct pixel format
    if (pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
        //We have an ARKIT buffer
        //Get the yPlane (Luma values)
        cv::Mat yPlane = cv::Mat(bufferHeight, bufferWidth, CV_8UC1, address);
        //Get cbcrPlane (Chroma values)
        int cbcrWidth = (int)CVPixelBufferGetWidthOfPlane(buffer,1);
        int cbcrHeight = (int)CVPixelBufferGetHeightOfPlane(buffer, 1);
        void *cbcrAddress = CVPixelBufferGetBaseAddressOfPlane(buffer, 1);
        //Since the CbCr Values are alternating we have 2 channels: Cb and Cr. Thus we need to use CV_8UC2 here.
        cv::Mat cbcrPlane = cv::Mat(cbcrHeight, cbcrWidth, CV_8UC2, cbcrAddress);
        //Split them apart so we can merge them with the luma values
        std::vector<cv::Mat> cbcrPlanes;
        cv::split(cbcrPlane, cbcrPlanes);

        cv::Mat cbPlane;
        cv::Mat crPlane;

        //Since we have a 4:2:0 format, cb and cr values are only present for each 2x2 luma pixels. Thus we need to enlargen them (by a factor of 2).
        cv::resize(cbcrPlanes[0], cbPlane, yPlane.size(), 0, 0, cv::INTER_LINEAR);
        cv::resize(cbcrPlanes[1], crPlane, yPlane.size(), 0, 0, cv::INTER_LINEAR);

        cv::Mat ycbcr;
        std::vector<cv::Mat> allPlanes = {yPlane, cbPlane, crPlane};
        cv::merge(allPlanes, ycbcr);

        //ycbcr now contains all three planes. We need to convert it from YCbCr to RGB so OpenCV can work with it

        NSLog(@"%s", cv::getBuildInformation().c_str());
        cv::cvtColor(ycbcr, converted, cv::COLOR_YCrCb2RGB);
    } else {
        //Probably RGB so just use that.
        int bytePerRow = (int)CVPixelBufferGetBytesPerRowOfPlane(buffer, 0);
        converted = cv::Mat(bufferHeight, bufferWidth, CV_8UC3, address, bytePerRow).clone();
    }
//    PNG specific compression parameters. Use "cv::IMWRITE_JPEG_QUALITY" for jpeg.
    std::vector<int> compression_params;
    compression_params.push_back(cv::IMWRITE_PNG_COMPRESSION);
    compression_params.push_back(0);
    cv::imwrite([filePath UTF8String], converted, compression_params);

    //Since we clone the cv::Mat no need to keep the Buffer Locked while we work on it.
    CVPixelBufferUnlockBaseAddress(buffer, 0);
}


+(void) writeYcbcr: (NSArray *) paths withFrame:(ARFrame *) frame {
    CVPixelBufferRef buffer = frame.capturedImage;
    cv::Mat mat;
    //Lock the base Address so it doesn't get changed!
    CVPixelBufferLockBaseAddress(buffer, 0);
    //Get the data from the first plane (Y)
    void *address =  CVPixelBufferGetBaseAddressOfPlane(buffer, 0);
    int bufferWidth = (int)CVPixelBufferGetWidthOfPlane(buffer,0);
    int bufferHeight = (int)CVPixelBufferGetHeightOfPlane(buffer, 0);
    //Get the pixel format
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(buffer);

    cv::Mat converted;
    //NOTE: CV_8UC3 means unsigned (0-255) 8 bits per pixel, with 3 channels!
    //Check to see if this is the correct pixel format
    if (pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange || pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
        //We have an ARKIT buffer
        //Get the yPlane (Luma values)
        cv::Mat yPlane = cv::Mat(bufferHeight, bufferWidth, CV_8UC1, address);
        auto path = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
//        auto yPath = [path URLByAppendingPathComponent:[NSString stringWithFormat:@"img_%lld_y.jpg", timeStamp]];
//        auto cbPath = [path URLByAppendingPathComponent:[NSString stringWithFormat:@"img_%lld_cb.jpg", timeStamp]];
//        auto crPath = [path URLByAppendingPathComponent:[NSString stringWithFormat:@"img_%lld_cr.jpg", timeStamp]];

        auto yPath = paths[0];
        auto cbPath = paths[1];
        auto crPath = paths[2];

        //Get cbcrPlane (Chroma values)
        int cbcrWidth = (int)CVPixelBufferGetWidthOfPlane(buffer,1);
        int cbcrHeight = (int)CVPixelBufferGetHeightOfPlane(buffer, 1);
        void *cbcrAddress = CVPixelBufferGetBaseAddressOfPlane(buffer, 1);
        //Since the CbCr Values are alternating we have 2 channels: Cb and Cr. Thus we need to use CV_8UC2 here.
        cv::Mat cbcrPlane = cv::Mat(cbcrHeight, cbcrWidth, CV_8UC2, cbcrAddress);
        //Split them apart so we can merge them with the luma values
        std::vector<cv::Mat> cbcrPlanes;
        cv::split(cbcrPlane, cbcrPlanes);

        std::vector<int> compression_params;
        compression_params.push_back(cv::IMWRITE_JPEG_QUALITY);
        compression_params.push_back(100);
        cv::imwrite([yPath UTF8String], yPlane, compression_params);
        cv::imwrite([cbPath UTF8String], cbcrPlanes[0], compression_params);
        cv::imwrite([crPath UTF8String], cbcrPlanes[1], compression_params);
    }

    //Since we clone the cv::Mat no need to keep the Buffer Locked while we work on it.
    CVPixelBufferUnlockBaseAddress(buffer, 0);
}

@end
