//
//  JZMainThreadRunLoopMonitor.m
//  性能监控
//
//  Created by tutu on 2021/7/10.
//  Copyright © 2021 tutu. All rights reserved.
//

#import "JZMainThreadRunLoopMonitor.h"

CFOptionFlags activities;
static dispatch_semaphore_t semaphore;
static dispatch_queue_t queue;

@interface JZMainThreadRunLoopMonitor()
@property (nonatomic, assign) int count;
@end

@implementation JZMainThreadRunLoopMonitor
+ (instancetype)monitor {
    static dispatch_once_t onceToken;
    static JZMainThreadRunLoopMonitor *monitor;
    dispatch_once(&onceToken, ^{
        monitor = [JZMainThreadRunLoopMonitor new];
    });
    return monitor;
}

- (void)startMonitor {
    [self initSignal];
    [self addRunLoopObserver];
}

- (void)initSignal {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        semaphore = dispatch_semaphore_create(0);
        queue = dispatch_queue_create("com.monitor.queue", NULL);
    });
}

- (void)addRunLoopObserver {
    CFRunLoopObserverRef observerRef = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        activities = activity;
        //唤醒
        dispatch_semaphore_signal(semaphore);
    });
    CFRunLoopAddObserver(CFRunLoopGetMain(), observerRef, kCFRunLoopCommonModes);
    
    dispatch_async(queue, ^{
        while (YES) {
            //如果当前线程超时了（阻塞了50毫秒），则子线程会继续往下执行，wait不为0。再判断当前RunLoop状态
            //如果在50毫秒内执行了dispatch_semaphore_signal，则证明主线程没有被阻塞
            long wait = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC));
            if (wait != 0) { //当前主线程阻塞了
                if (activities==kCFRunLoopAfterWaiting || activities==kCFRunLoopBeforeSources) {
                    if (self.count++ < 5) {
                        continue;
                    };
                    
                    NSLog(@"主线程卡顿了。。。");
                }
            }
            self.count = 0;
        }
    });
}

@end
