//
//  MAViewController.m
//  MACamera
//
//  Created by ma772528138@qq.com on 12/18/2018.
//  Copyright (c) 2018 ma772528138@qq.com. All rights reserved.
//

#import "MAViewController.h"
#import "MACameraController.h"

@interface MAViewController ()

@end

@implementation MAViewController

- (void)viewDidLoad{
    [super viewDidLoad];
        
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, 80, 80);
    btn.center = self.view.center;
    [btn setTitle:@"拍摄" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.view addSubview:btn];
    [btn addTarget:self action:@selector(showCamera:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)showCamera:(UIButton *)btn {
    [MACameraController allowCameraAndPhoto:^(BOOL allow) {
        if (allow) {
            MACameraController *camera = [[MACameraController alloc] init];
            [self presentViewController:camera animated:YES completion:nil];
        }
    }];
}

- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
