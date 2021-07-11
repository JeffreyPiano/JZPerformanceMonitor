//
//  ViewController.m
//  JZPerformanceMonitor
//
//  Created by tutu on 2021/7/11.
//  Copyright © 2021 tutu. All rights reserved.
//

#import "ViewController.h"
#import "JZAppFluencyMonitor.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[JZAppFluencyMonitor monitor] startMonitor];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (int i=0; i<10000; i++) {
            NSLog(@"111");
        }
        [[JZAppFluencyMonitor monitor] stopMonitor];
    });
}


@end
