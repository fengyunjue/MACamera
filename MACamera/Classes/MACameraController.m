//
//  MACameraController.m
//  MACamera
//
//  Created by fengyunjue on 2018/4/26.
//  Copyright © 2018年 fengyunjue. All rights reserved.
//

#import "MACameraController.h"
#import <Photos/Photos.h>

//类型枚举
enum {
    PhotoType,
    VideoType
};
typedef NSInteger MAShootingType;


@interface ShootingButton : UIView

@property (nonatomic, copy) void(^shootingStart)(MAShootingType type);
@property (nonatomic, copy) void(^shootingEnd)(MAShootingType type);
/// 录制时间, 默认10s
@property (nonatomic, assign) NSTimeInterval  time;

@end

@interface ShootingCenterButton : UIView

+(ShootingCenterButton*)getShootingCenterButton:(CGFloat)maxLineW minLineWidth:(CGFloat)minLineW lineColor:(UIColor*)lineColor centerColor:(UIColor*)centerColor;

@property (nonatomic, copy) void(^shootingStart)(MAShootingType type);
@property (nonatomic, copy) void(^shootingEnd)(MAShootingType type);

@end


@interface PlayerView : UIView
@property (nonatomic , strong)NSURL * url;
@property (nonatomic , strong)UIImage * image;
@property (nonatomic , strong) AVPlayerItem * playerItem;
@property (nonatomic , strong) AVPlayer * player;
@property (nonatomic , strong) UIImageView * imageView;
@property (nonatomic , strong) AVPlayerLayer *playerLayer;
-(void)removeSubViews;
@end

@interface MACameraController ()<AVCaptureFileOutputRecordingDelegate>

@property (nonatomic , strong) ShootingButton * shootingButton;
@property (nonatomic , strong) UIButton * closeButton;
@property (nonatomic , strong) UIButton * leftButton;
@property (nonatomic , strong) UIButton * rightButton;
// 切换摄像头按钮
@property (nonatomic , strong) UIButton * invertButton;

//播放view
@property (nonatomic , strong) PlayerView * palyerView;
//显示视频的内容
@property (nonatomic , strong) UIView * userCamera;
//负责输入和输出设置之间的数据传递
@property (strong,nonatomic)   AVCaptureSession *captureSession;
//负责从AVCaptureDevice获得输入数据
@property (strong,nonatomic)   AVCaptureDeviceInput *captureDeviceInput;
//照片输出流
@property (strong,nonatomic) AVCaptureStillImageOutput *captureStillImageOutput;
//视频输出流
@property (strong,nonatomic)   AVCaptureMovieFileOutput *captureMovieFileOutput;
//相机拍摄预览图层
@property (strong,nonatomic)   AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
//后台任务标示符
@property (nonatomic, assign)  UIBackgroundTaskIdentifier backgroundTaskIdentifier;
//保存的Url
@property (nonatomic, strong)  NSURL * localMovieUrl;
//拍照的照片
@property (nonatomic, strong)UIImage * image;

@property (nonatomic, assign) BOOL  isVideo;
@end

@implementation MACameraController

- (instancetype)init{
    self = [super init];
    if (self) {
        _time = 10;
    }
    return self;
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self.captureSession startRunning];
    });
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.captureSession stopRunning];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [UIApplication sharedApplication].statusBarHidden = YES;
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [UIApplication sharedApplication].statusBarHidden = NO;
}

- (BOOL)prefersStatusBarHidden{
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    // 用来显示录像内容
    _userCamera = [[UIView alloc]initWithFrame:self.view.bounds];
    _userCamera.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_userCamera];
    
    // 小中心录制，拍照按钮
    _shootingButton =[[ShootingButton alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 85 - 50, 85, 85)];
    _shootingButton.center = CGPointMake(self.view.center.x, self.shootingButton.center.y);
    [self.view addSubview:_shootingButton];
    _shootingButton.time = _time;
    __weak typeof(self) weakSelf = self;
    _shootingButton.shootingStart = ^(MAShootingType type) {
        weakSelf.isVideo = type == VideoType;
        if (type == VideoType) {
            [weakSelf startRecordVideo];
        }
    };
    _shootingButton.shootingEnd = ^(MAShootingType type) {
        [weakSelf buttonAnimation:YES];
        
        //取出播放视图
        [weakSelf.view insertSubview:weakSelf.palyerView aboveSubview:weakSelf.userCamera];
        if (type == PhotoType) {
            [weakSelf takePhoto:weakSelf.palyerView];
        }else{
            [weakSelf stopRecordVideo];
            weakSelf.palyerView.url = weakSelf.localMovieUrl;
        }
    };
    
    // 关闭按钮
    _closeButton = [[UIButton alloc]initWithFrame:CGRectMake(self.shootingButton.frame.origin.x - 40 - 40, 0, 40, 40)];
    self.closeButton.center = CGPointMake(self.closeButton.center.x, self.shootingButton.center.y);
    [self.view addSubview:_closeButton];
    [_closeButton setImage:[MACameraController imageNamed:@"MACamera.bundle/cancel"] forState:normal];
    _closeButton.tag = 2;
    [_closeButton addTarget:self action:@selector(shootingClickButton:) forControlEvents:UIControlEventTouchUpInside];
    
    // 左侧按钮
    _leftButton = [[UIButton alloc]initWithFrame:CGRectMake(0 , 0, 70, 70)];
    self.leftButton.center = self.shootingButton.center;
    [self.view addSubview:_leftButton];
    _leftButton.hidden = YES;
    _leftButton.tag = 1;
    _leftButton.backgroundColor = [UIColor greenColor];
    [_leftButton setImage:[MACameraController imageNamed:@"return"] forState:normal];
    _leftButton.layer.cornerRadius=35;
    _leftButton.layer.masksToBounds = YES;
    [_leftButton addTarget:self action:@selector(shootingClickButton:) forControlEvents:UIControlEventTouchUpInside];
    
    // 右侧按钮
    _rightButton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 70, 70)];
    self.rightButton.center = self.shootingButton.center;
    [self.view addSubview:_rightButton];
    _rightButton.hidden = YES;
    _rightButton.layer.cornerRadius=35;
    _rightButton.tag = 3;
    _rightButton.layer.masksToBounds = YES;
    [_rightButton setImage:[MACameraController imageNamed:@"sure"] forState:normal];
    [_rightButton addTarget:self action:@selector(shootingClickButton:) forControlEvents:UIControlEventTouchUpInside];
    
    // 切换摄像头按钮
    _invertButton = [[UIButton alloc]initWithFrame:CGRectMake(self.view.frame.size.width - 32 - 30, 40, 32, 26)];
    [self.view addSubview:_invertButton];
    [_invertButton setImage:[MACameraController imageNamed:@"switchover"] forState:UIControlStateNormal];
    _invertButton.tag = 4;
    [_invertButton addTarget:self action:@selector(shootingClickButton:) forControlEvents:UIControlEventTouchUpInside];
    
    // 展示VC
    _palyerView = [[PlayerView alloc]initWithFrame:self.view.bounds];
    
    // 设置camera
    [self seingUserCamera];
}

- (void)shootingClickButton:(UIButton *)button {
    NSInteger index = button.tag;
    if (index==1) {//重新拍摄
        [self buttonAnimation:NO];
        [self.captureSession startRunning];
        [self.palyerView removeSubViews];
        [self.palyerView.player pause];
    }else if (index == 2){// 关闭按钮
        [self dismissViewControllerAnimated:YES completion:nil];
    }else if (index == 3) {// 完成拍摄
        if (self.cameraCompletion) {
            __weak typeof(self) weakSelf = self;
            self.cameraCompletion(weakSelf, self.localMovieUrl, self.image, self.isVideo);
        }
    }else if (index == 4){// 切换摄像头
        [self rotateCamera];
    }
}
-(void)buttonAnimation:(BOOL)open{
    _closeButton.hidden = open;
    _shootingButton.hidden =open;
    _invertButton.hidden = open;
    _leftButton.hidden = !open;
    _rightButton.hidden = !open;
    
    CGFloat spacing = (self.view.frame.size.width - 100) / 3;
    if (open) {
        [UIView animateWithDuration:0.4 animations:^{
            self.leftButton.transform = CGAffineTransformTranslate(self.leftButton.transform, -spacing, 0);
            self.rightButton.transform = CGAffineTransformTranslate(self.rightButton.transform, spacing, 0);
        }];
        return;
    }
    //隐藏
    _leftButton.transform = CGAffineTransformIdentity;
    _rightButton.transform = CGAffineTransformIdentity;
}
#pragma mark ------AVCaptureFileOutputRecordingDelegate 实现代理-------statr------

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
//    NSLog(@"开始录制");
}

-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
//    NSLog(@"完成录制");
}

-(void)seingUserCamera{
    //初始化会话
    _captureSession=[[AVCaptureSession alloc]init];

    // 设置太高的分辨率,就不能切换到前置摄像头了
//    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset3840x2160]) {//设置分辨率
//        _captureSession.sessionPreset=AVCaptureSessionPresetMedium;
//    }
    
    //获得输入设备
    AVCaptureDevice *captureDevice=[self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];//取得后置摄像头
    if (!captureDevice) { NSLog(@"取得后置摄像头时出现问题."); return; }

    NSError *error=nil;
    //根据输入设备初始化设备输入对象，用于获得输入数据
    _captureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:&error];
    if (error) { NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription); return; }
    
    //添加一个音频输入设备
    AVCaptureDeviceInput *audioCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice: [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio] error:&error];
    if (error) { NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription); return;  }
    
    //初始化设备输出对象，用于获得输出数据
    _captureMovieFileOutput=[[AVCaptureMovieFileOutput alloc]init];
    
    //将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
        [_captureSession addInput:audioCaptureDeviceInput];
        AVCaptureConnection *captureConnection=[_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([captureConnection isVideoStabilizationSupported ]) {
            captureConnection.preferredVideoStabilizationMode=AVCaptureVideoStabilizationModeAuto;
        }
    }
    
    //将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureMovieFileOutput]) {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
   /*-----------*/
    //照片输出
     _captureStillImageOutput=[[AVCaptureStillImageOutput alloc]init];
    [_captureStillImageOutput setOutputSettings:[[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil]];//输出设置
    //将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureStillImageOutput]) {
        [_captureSession addOutput:_captureStillImageOutput];
    }
    /*-----------*/
    
    //创建视频预览层，用于实时展示摄像头状态
    _captureVideoPreviewLayer=[[AVCaptureVideoPreviewLayer alloc]initWithSession:self.captureSession];
    
    CALayer *layer=self.userCamera.layer;
    layer.masksToBounds=YES;
    
    _captureVideoPreviewLayer.frame=layer.bounds;
    _captureVideoPreviewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;//填充模式
    //将视频预览层添加到界面中
    [layer addSublayer:_captureVideoPreviewLayer];
    
}

/**
 切换相机
 */
- (void)rotateCamera {
    AVCaptureDevicePosition currentPosition=[[_captureDeviceInput device] position];
    AVCaptureDevicePosition toChangePosition = AVCaptureDevicePositionFront;//前
    if (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition == AVCaptureDevicePositionFront) {
        toChangePosition = AVCaptureDevicePositionBack;//后
    }
    AVCaptureDevice *toChangeDevice = [self getCameraDeviceWithPosition:toChangePosition];
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];

    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [_captureSession stopRunning];
    [_captureSession beginConfiguration];
    //移除原有输入对象
    [_captureSession removeInput:_captureDeviceInput];
    //添加新的输入对象
    if ([_captureSession canAddInput:toChangeDeviceInput]) {
        [_captureSession addInput:toChangeDeviceInput];
        _captureDeviceInput = toChangeDeviceInput;
    }
    //提交会话配置
    [_captureSession commitConfiguration];
    [_captureSession startRunning];
}

/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition ) position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

// 准备录制视频
- (void)startRecordVideo{
    
    self.invertButton.hidden = YES;
    self.closeButton.hidden = YES;
    
    AVCaptureConnection *connection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    AVCaptureDevicePosition position = [[_captureDeviceInput device] position];
    if (position == AVCaptureDevicePositionFront || position == AVCaptureDevicePositionUnspecified) {
        connection.videoMirrored = YES;
    }else{
        connection.videoMirrored = NO;
    }
    if (![self.captureSession isRunning]) {
        //如果捕获会话没有运行
        [self.captureSession startRunning];
    }
    //根据连接取得设备输出的数据
    if (![self.captureMovieFileOutput isRecording]) {
        //如果输出 没有录制
        //如果支持多任务则则开始多任务
        if ([[UIDevice currentDevice] isMultitaskingSupported]) {
            self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
            [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
        }
        
        //预览图层和视频方向保持一致
        connection.videoOrientation = [self.captureVideoPreviewLayer connection].videoOrientation;
        //开始录制视频使用到了代理 AVCaptureFileOutputRecordingDelegate 同时还有录制视频保存的文件地址的
        [self.captureMovieFileOutput startRecordingToOutputFileURL:self.localMovieUrl recordingDelegate:self];
    }
    [self takePhoto:nil];
}

//停止录制
-(void)stopRecordVideo{
    if ([self.captureMovieFileOutput isRecording]) {
        [self.captureMovieFileOutput stopRecording];
    }//把捕获会话也停止的话，预览视图就停了
    if ([self.captureSession isRunning]) {
        [self.captureSession stopRunning];
    }
}

//开始拍照
-(void)takePhoto:(PlayerView *)playerView{
    //根据设备输出获得连接
    AVCaptureConnection *captureConnection=[self.captureStillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    AVCaptureDevicePosition position = [[_captureDeviceInput device] position];
    if (position == AVCaptureDevicePositionFront || position == AVCaptureDevicePositionUnspecified) {
        captureConnection.videoMirrored = YES;
    }else{
        captureConnection.videoMirrored = NO;
    }
    //根据连接取得设备输出的数据
    __weak typeof(self) weakSelf = self;
    [self.captureStillImageOutput captureStillImageAsynchronouslyFromConnection:captureConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer) {
            
            NSData *imageData=[AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *image=[UIImage imageWithData:imageData];
            weakSelf.image = image;
            playerView.image = image;
        }
    }];
}

#pragma mark 设置视频保存地址
- (NSURL *)localMovieUrl{
    if (_localMovieUrl == nil) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm"];
        NSString *outputFilePath=[NSTemporaryDirectory() stringByAppendingString:[NSString stringWithFormat:@"%@.mp4",[formatter stringFromDate:[NSDate date]]]];
        NSURL *fileUrl=[NSURL fileURLWithPath:outputFilePath];
        _localMovieUrl = fileUrl;
    }
    return _localMovieUrl;
}

+ (void)movFileTransformToMP4WithSourceUrl:(NSURL *)sourceUrl completion:(void(^)(NSString *Mp4FilePath))comepleteBlock session:(void(^)(AVAssetExportSession *session))sessionBlock{
    
    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:sourceUrl options:nil];
    
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
    
    AVAssetExportSession *exportSession;
    if ([compatiblePresets containsObject:AVAssetExportPresetMediumQuality]) {
        
        exportSession = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetMediumQuality];
        NSString *fileStr = [[sourceUrl.absoluteString componentsSeparatedByString:@"/"].lastObject.uppercaseString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *fileName = [[fileStr componentsSeparatedByString:@"."].firstObject.uppercaseString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *uniqueName = [NSString stringWithFormat:@"%@.mp4",fileName];
        NSArray *docPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docPath = docPaths.lastObject;
        NSString * resultPath = [docPath stringByAppendingPathComponent:uniqueName];
        
        exportSession.outputURL = [NSURL fileURLWithPath:resultPath];
        exportSession.outputFileType = AVFileTypeMPEG4;
        exportSession.shouldOptimizeForNetworkUse = YES;
        
        //如有此文件则直接返回
        if ([[NSFileManager defaultManager] fileExistsAtPath:resultPath]) {
            comepleteBlock(resultPath);
            return;
        }
        
        [exportSession exportAsynchronouslyWithCompletionHandler:^(void) {
             switch (exportSession.status) {
                     
                 case AVAssetExportSessionStatusUnknown: {
//                     NSLog(@"视频格式转换出错Unknown");
                     sessionBlock(exportSession);
                 }
                     break;
                 case AVAssetExportSessionStatusWaiting: {
//                     NSLog(@"视频格式转换出错Waiting");
                     sessionBlock(exportSession);
                 }
                     break;
                 case AVAssetExportSessionStatusExporting: {
//                     NSLog(@"视频格式转换出错Exporting");
                     sessionBlock(exportSession);
                 }
                     break;
                 case AVAssetExportSessionStatusCompleted: {
                     comepleteBlock(resultPath);
//                     NSLog(@"mp4 file size:%lf MB",[NSData dataWithContentsOfURL:exportSession.outputURL].length/1024.f/1024.f);
//                     NSData *da = [NSData dataWithContentsOfFile:resultPath];
//                     NSLog(@"da:%lu",(unsigned long)da.length);
                 }
                     break;
                 case AVAssetExportSessionStatusFailed: {
//                     NSLog(@"视频格式转换出错Unknown");
                     sessionBlock(exportSession);
                 }
                     break;
                 case AVAssetExportSessionStatusCancelled: {
//                     NSLog(@"视频格式转换出错Cancelled");
                     sessionBlock(exportSession);
                 }
                     break;
             }
         }];
        
    }
}


+ (void)allowCameraAndPhoto:(void (^)(BOOL))completion{
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied) { // 无相机权限 做一个友好的提示
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法使用相机" message:@"请在iPhone的""设置-隐私-相机""中允许访问相机" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        if (completion) {
            completion(NO);
        }
    } else if (authStatus == AVAuthorizationStatusNotDetermined) { // fix issue 466, 防止用户首次拍照拒绝授权时相机页黑屏
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self allowCameraAndPhoto:completion];
                });
            }
        }];
        // 拍照之前还需要检查相册权限
    } else if ([PHPhotoLibrary authorizationStatus] == 2) { // 已被拒绝，没有相册权限，将无法保存拍的照片
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法访问相册" message:@"请在iPhone的""设置-隐私-相册""中允许访问相册" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        if (completion) {
            completion(NO);
        }
    } else if ([PHPhotoLibrary authorizationStatus] == 0) { // 未请求过相册权限
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self allowCameraAndPhoto:completion];
                });
            }];
        });
    } else {
        if (completion) {
            completion(YES);
        }
    }
}

+ (UIImage *)imageNamed:(NSString *)name {
    UIImage *image = [UIImage imageNamed:[@"MACamera.bundle" stringByAppendingPathComponent:name]];
    if (!image) {
        image = [UIImage imageNamed:[@"Frameworks/MACamera.framework/MACamera.bundle" stringByAppendingPathComponent:name]];
    }
    if (!image) {
        image = [UIImage imageNamed:name];
    }
    return image;
}

@end


@implementation PlayerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        //注册通知
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(runLoopTheMovie:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    }
    return self;
}

//视频结束后重新播放
- (void)runLoopTheMovie:(NSNotification *)n{
    AVPlayerItem * p = [n object];
    //关键代码
    [p seekToTime:kCMTimeZero];
    [self.player play];
}
-(void)setUrl:(NSURL *)url{
    // 1、得到视频的URL
    NSURL *movieURL = url;
    // 2、根据URL创建AVPlayerItem
    self.playerItem   = [AVPlayerItem playerItemWithURL:movieURL];
    // 3、把AVPlayerItem 提供给 AVPlayer
    self.player     = [AVPlayer playerWithPlayerItem:self.playerItem];
    // 4、AVPlayerLayer 显示视频。
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    _playerLayer.frame       = self.bounds;
    //设置边界显示方式
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    
    [self.layer insertSublayer:_playerLayer atIndex:0];
    
    [self.player play];
    
}
-(void)setImage:(UIImage *)image {
    _imageView = [[UIImageView alloc]init];
    _imageView.frame = self.bounds;
    _imageView.image = image;
    [self addSubview:_imageView];
}
-(void)removeSubViews {
    [self.player pause];
    [_imageView removeFromSuperview];
    [self.playerLayer removeFromSuperlayer];
    [self removeFromSuperview];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

@end


@interface ShootingButton ()
@property (nonatomic , strong)  ShootingCenterButton * centerButton;
@property (nonatomic , strong) CAShapeLayer * progressLayer;
@property (nonatomic , strong) CADisplayLink * displayLink;
@property (nonatomic , assign) CGFloat progressValue;
@end
@implementation ShootingButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _time = 10;
        // -----进度圈内部按钮----
        ShootingCenterButton * centerButton = [ShootingCenterButton getShootingCenterButton:20 minLineWidth:10 lineColor:nil centerColor:nil];
        centerButton.frame = CGRectMake(9, 9, frame.size.width - 18, frame.size.height - 18);
        _centerButton = centerButton;
        [self addSubview:centerButton];
        
        // -----进度圈----
        _progressLayer    = [CAShapeLayer layer];
        _progressLayer.strokeColor   = [UIColor colorWithRed:26.0 / 255.0 green:173.0 / 255.0 blue:25.0 / 255.0 alpha:1].CGColor;    //设置划线颜色
        _progressLayer.fillColor     = [UIColor clearColor].CGColor;   //设置填充颜色
        _progressLayer.lineWidth     = 3;          //设置线宽
        _progressLayer.strokeStart   = 0;
        _progressLayer.strokeEnd     = 0;        //设置轮廓结束位置
        //旋转到垂直方向
        CATransform3D turnTrans = CATransform3DMakeRotation(-M_PI / 2, 0, 0, 1);
        _progressLayer.transform= turnTrans;
        [self.layer addSublayer:_progressLayer];
        
        __weak typeof(self) weakSelf = self;
        centerButton.shootingStart = ^(MAShootingType type) {
            //长按的手势（开启定时器）
            if (type==VideoType) {
                weakSelf.progressLayer.strokeColor = [UIColor greenColor].CGColor;
                weakSelf.displayLink = [CADisplayLink displayLinkWithTarget:weakSelf selector:@selector(changeProgerss)];
                [weakSelf.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
            }
            
            if (weakSelf.shootingStart) {
                weakSelf.shootingStart(type);
            }
        };
        centerButton.shootingEnd = ^(MAShootingType type) {
            if (type == VideoType) {
                if (weakSelf.displayLink) { // 避免重复调用,如果displayLink不存在,说明已经结束了
                    [weakSelf stopProress];
                    if (weakSelf.shootingEnd) {
                        weakSelf.shootingEnd(type);
                    }
                }
            }else{ //回调自己的代理(结束)
                if (weakSelf.shootingEnd) {
                    weakSelf.shootingEnd(type);
                }
            }
        };
    }
    return self;
}

-(void)layoutSubviews{
    [super layoutSubviews];
    self.progressLayer.frame = self.bounds;
    self.progressLayer.path = [UIBezierPath bezierPathWithOvalInRect:self.bounds].CGPath; //设置绘制路径
}
#pragma mark action --------------事件处理逻辑----------------

/**
 修改进度要的状态（定时器实时调用的方法）
 */
-(void)changeProgerss{
    double speed = (1.0/self.time) / 60.0;//拍摄的时间
    self.progressValue = self.progressValue + speed;
    self.progressLayer.strokeEnd = self.progressValue;
    if (self.progressValue >= 1.05) {
        self.centerButton.shootingEnd(VideoType);
    }
}

/**
 结束视频的拍摄
 */
-(void)stopProress{
    self.progressValue = 0;
    self.progressLayer.strokeEnd =   self.progressValue;
    self.progressLayer.strokeColor = [UIColor clearColor].CGColor;
    [self.displayLink invalidate];
    self.displayLink = nil;
}

@end

@interface ShootingCenterButton()
@property(nonatomic , strong) UIBezierPath * path;
@property(nonatomic , strong) CAShapeLayer * centerLayer;
@end

@implementation ShootingCenterButton

+(ShootingCenterButton*)getShootingCenterButton:(CGFloat)maxLineW minLineWidth:(CGFloat)minLineW lineColor:(UIColor*)lineColor centerColor:(UIColor*)centerColor{
    //初始化一个实例对象
    ShootingCenterButton * centerButton = [[ShootingCenterButton alloc]init];
    centerButton.centerLayer = [CAShapeLayer layer];
    centerButton.centerLayer.frame         = centerButton.bounds;
    centerButton.centerLayer.path          = centerButton.path.CGPath; //设置绘制路径
    centerButton.centerLayer.strokeColor   = [UIColor colorWithRed:218.0 / 255.0 green:217.0 / 255.0 blue:214.0 / 255.0 alpha:1].CGColor;      //设置划线颜色
    centerButton.centerLayer.fillColor     = [UIColor whiteColor].CGColor;   //设置填充颜色
    centerButton.centerLayer.lineWidth     = 13;          //设置线宽
    centerButton.centerLayer.strokeEnd     = 1;        //设置轮廓结束位置
    [centerButton.layer addSublayer:centerButton.centerLayer];
    return centerButton;
}
-(id)initWithFrame:(CGRect)frame{
    if (self=[super initWithFrame:frame]) {
        
        UITapGestureRecognizer * singeTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(singleClick)];
        [self addGestureRecognizer:singeTap];
        UILongPressGestureRecognizer * longTap = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(longClick:)];
        [self addGestureRecognizer:longTap];
        
    }
    return self;
}

//重写布局下子控制器
-(void)layoutSubviews{
    [super layoutSubviews];
    self.centerLayer.frame    =  self.bounds;
    self.centerLayer.path     =  [UIBezierPath bezierPathWithOvalInRect:self.bounds].CGPath; //设置绘制路径
}

/**
 长按事件
 
 @param tap UILongPressGestureRecognizer
 */
-(void)longClick:(UILongPressGestureRecognizer*)tap{
    //手势开始
    if (tap.state==UIGestureRecognizerStateBegan){
        self.centerLayer.lineWidth = 20;
        if (self.shootingStart) {  //视频开始拍摄
            self.shootingStart(VideoType);
        }
    }
    //判断手势结束
    if (tap.state==UIGestureRecognizerStateEnded) {
        self.centerLayer.lineWidth = 10;
        if (self.shootingEnd) {  //视频结束拍摄
            self.shootingEnd(VideoType);
        }
    }
}
//单击事件
-(void)singleClick{
    if (self.shootingStart) { //照片开始拍摄
        self.shootingStart(PhotoType);
    }
    if (self.shootingEnd) { //照片结束拍摄
        self.shootingEnd(PhotoType);
    }
}

@end
