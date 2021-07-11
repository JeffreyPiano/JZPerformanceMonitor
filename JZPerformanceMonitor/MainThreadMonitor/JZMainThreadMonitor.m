//
//  JZMainThreadMonitor.m
//  PMainThreadWatcherDemo
//
//  Created by tutu on 2021/7/9.
//  Copyright © 2021 music4kid. All rights reserved.
//

#import "JZMainThreadMonitor.h"

#include <signal.h>
#include <pthread.h>
#include <execinfo.h>
#include <libkern/OSAtomic.h>

#define MainThreadMonitor_Interval 1.0f
#define MainThreadFRAME_Interval 16.0f/1000.0f

#define Notification_MainThreadMonitor_Ping    @"Notification_MainThreadMonitor_Ping"
#define Notification_MainThreadMonitor_Pong    @"Notification_MainThreadMonitor_Pong"

#define CALLSTACK_SIG SIGUSR1
static pthread_t mainJZThreadID;

static void thread_singal_handler(int sig) {
    NSLog(@"main thread catch signal: %d", sig);
    
    if (sig != CALLSTACK_SIG) {
        return;
    }
    
    NSArray<NSString *> * stacks = [NSThread callStackSymbols];
    id delegate = [JZMainThreadMonitor shareInstance].delegate;
    if (delegate && [delegate respondsToSelector:@selector(onMainThreadSlowStackMonitor:)]) {
        [delegate onMainThreadSlowStackMonitor:stacks];
    } else {
        for (NSString* call in stacks) {
            NSLog(@"%@\n", call);
        }
    }
}

static void install_signal_handler() {
    signal(CALLSTACK_SIG, thread_singal_handler);
}

static void printMainThreadCallStack()
{
    pthread_kill(mainJZThreadID, CALLSTACK_SIG);
}

@interface JZMainThreadMonitor()
@property (nonatomic, strong) dispatch_source_t pingTimer;
@property (nonatomic, strong) dispatch_source_t pongTimer;
@end

@implementation JZMainThreadMonitor

+ (instancetype)shareInstance {
    static dispatch_once_t onceToken;
    static JZMainThreadMonitor *monitor;
    dispatch_once(&onceToken, ^{
        monitor = [JZMainThreadMonitor new];
    });
    return monitor;
}

- (void)startMonitor {
    //监控主线程通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainThreadMonitorPingNotification) name:Notification_MainThreadMonitor_Ping object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mainThreadMonitorPongNotification) name:Notification_MainThreadMonitor_Pong object:nil];
    
    install_signal_handler();
    mainJZThreadID = pthread_self();
    
    uint64_t interval = MainThreadMonitor_Interval * NSEC_PER_SEC;
    self.pingTimer = createGCDTimer(interval, interval/1000, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self pingMainThread];
    });
}

- (void)pingMainThread {
    //创建定时器
    uint64_t interval = MainThreadFRAME_Interval * NSEC_PER_SEC;
    self.pongTimer = createGCDTimer(interval, interval/1000, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
           [self pongTimeOut];
       });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:Notification_MainThreadMonitor_Ping object:nil];
    });
}

- (void)pongTimeOut {
    [self canclePoneTimer];
    printMainThreadCallStack();
}

- (void)mainThreadMonitorPingNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:Notification_MainThreadMonitor_Pong object:nil];
}

- (void)mainThreadMonitorPongNotification {
    [self canclePoneTimer];
}

- (void)canclePoneTimer {
    if (self.pongTimer) {
        dispatch_source_cancel(self.pongTimer);
        self.pongTimer = nil;
    }
}

dispatch_source_t createGCDTimer(uint64_t interval, uint64_t leeway, dispatch_queue_t queue, dispatch_block_t block) {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    if (timer) {
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, interval), interval, leeway);
        dispatch_source_set_event_handler(timer, block);
        dispatch_resume(timer);
    }
    return timer;
}

@end
