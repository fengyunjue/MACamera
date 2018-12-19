//
//  MAViewController.m
//  MACamera
//
//  Created by ma772528138@qq.com on 12/18/2018.
//  Copyright (c) 2018 ma772528138@qq.com. All rights reserved.
//

#import "MAViewController.h"
#import "MACameraController.h"
#import <AVFoundation/AVFoundation.h>

@interface MAPlayerView : UIView
@property (nonatomic , strong)NSURL * url;
@property (nonatomic , strong)UIImage * image;
@property (nonatomic , strong) AVPlayerItem * playerItem;
@property (nonatomic , strong) AVPlayer * player;
@property (nonatomic , strong) UIImageView * imageView;
@property (nonatomic , strong) AVPlayerLayer *playerLayer;

@end

@interface MAViewController ()

@property (nonatomic, weak) MAPlayerView *playerView;

@end

@implementation MAViewController

- (void)viewDidLoad{
    [super viewDidLoad];
    
    MAPlayerView *player = [[MAPlayerView alloc] initWithFrame:self.view.bounds];
    player.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:player];
    self.playerView = player;
    
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, 80, 80);
    btn.center = self.view.center;
    [btn setTitle:@"拍摄" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [self.view addSubview:btn];
    [btn addTarget:self action:@selector(showCamera:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)showCamera:(UIButton *)btn {
    __weak typeof(self) weakSelf = self;
    [MACameraController allowCameraAndPhoto:^(BOOL allow) {
        if (allow) {
            MACameraController *camera = [[MACameraController alloc] init];
            camera.cameraCompletion = ^(MACameraController *shootingVC, NSURL *videoURL, UIImage *image, BOOL isVideo) {
                if (isVideo) {
                    weakSelf.playerView.url = videoURL;
                }else{
                    weakSelf.playerView.image = image;
                }
                [shootingVC dismissViewControllerAnimated:YES completion:nil];
            };
            [self presentViewController:camera animated:YES completion:nil];
        }
    }];
}

- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end



@implementation MAPlayerView

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
    [self removeContent];
    
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
    [self removeContent];
    _imageView = [[UIImageView alloc]initWithFrame:self.bounds];
    _imageView.image = image;
    [self addSubview:_imageView];
}
-(void)removeContent {
    [self.player pause];
    [_imageView removeFromSuperview];
    [self.playerLayer removeFromSuperlayer];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

@end
