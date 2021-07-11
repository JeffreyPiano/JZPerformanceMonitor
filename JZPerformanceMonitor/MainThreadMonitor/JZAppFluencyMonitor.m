//
//  JZAppFluencyMonitor.m
//  性能监控
//
//  Created by tutu on 2021/7/10.
//  Copyright © 2021 tutu. All rights reserved.
//

#import "JZAppFluencyMonitor.h"

static dispatch_semaphore_t semaphore;
static dispatch_queue_t queue;

@interface JZAppFluencyMonitor()
@property (nonatomic, assign) BOOL timeOut;
@property (nonatomic, assign) BOOL isMonitoring;
@end

@implementation JZAppFluencyMonitor
+ (instancetype)monitor {
    static dispatch_once_t onceToken;
    static JZAppFluencyMonitor *monitor;
    dispatch_once(&onceToken, ^{
        monitor = [JZAppFluencyMonitor new];
    });
    return monitor;
}

- (void)initSignal {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        semaphore = dispatch_semaphore_create(0);
        queue = dispatch_queue_create("com.monitor.queue", NULL);
    });
}

- (void)startMonitor {
    if (_isMonitoring) return ;
    _isMonitoring = YES;
    
    [self initSignal];
    __weak typeof(self) weakSelf = self;
    dispatch_async(queue, ^{
        while (weakSelf.isMonitoring) {
            __block BOOL timeOut = YES;
            //主线程是否能在50毫秒内唤醒
            dispatch_async(dispatch_get_main_queue(), ^{
                timeOut = NO;
                dispatch_semaphore_signal(semaphore);
            });
            
            //50毫秒内没有唤醒，证明主线程被阻塞了
            [NSThread sleepForTimeInterval:0.05];
            if (timeOut) {
                NSLog(@"主线程卡顿。。。");
            }
            
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        }
    });
}

- (void)stopMonitor {
    if (!_isMonitoring) return ;
    if (_isMonitoring) _isMonitoring = NO;
}
@end
