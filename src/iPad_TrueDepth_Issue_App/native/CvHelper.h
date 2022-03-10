//
//  CvHelper.h
//  iPad_TrueDepth_Issue_App
//
//  Created by Thomas Lindemeier on 2022.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CvHelper : NSObject

// Saves the depth buffer as a PNG file.
+(void) writeDepthPng: (NSString *) filePath withData:(AVDepthData *) data;

// Used to write RGB data of AR frame, useful for saving ycbcr buffer.
+(void) writeRgb: (NSString *) filePath withFrame:(ARFrame *) frame;

// Used to write ycbcr buffer data into separate files.
+(void) writeYcbcr: (NSArray *) paths withFrame:(ARFrame *) frame;

@end

NS_ASSUME_NONNULL_END
