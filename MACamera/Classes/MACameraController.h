//
//  MACameraController.h
//  MACamera
//
//  Created by fengyunjue on 2018/4/26.
//  Copyright © 2018年 fengyunjue. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface MACameraController : UIViewController

/**
 拍照完成的block
 */
@property (nonatomic, copy) void (^cameraCompletion)(MACameraController *shootingVC, NSURL *videoURL, UIImage *image, BOOL isVideo);

/**
 视频录制的时间,默认10s
 */
@property (nonatomic, assign) NSTimeInterval  time;

+ (void)movFileTransformToMP4WithSourceUrl:(NSURL *)sourceUrl completion:(void(^)(NSString *Mp4FilePath))comepleteBlock session:(void(^)(AVAssetExportSession *session))sessionBlock;

+ (void)allowCameraAndPhoto:(void (^)(BOOL allow))completion;

+ (UIImage *)imageNamed:(NSString *)name;

@end
