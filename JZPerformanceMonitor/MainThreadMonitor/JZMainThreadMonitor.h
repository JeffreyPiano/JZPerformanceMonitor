//
//  JZMainThreadMonitor.h
//  PMainThreadWatcherDemo
//
//  Created by tutu on 2021/7/9.
//  Copyright © 2021 music4kid. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol JZMainThreadMonitorDelegate <NSObject>
@optional
- (void)onMainThreadSlowStackMonitor:(NSArray *)stack;

@end

@interface JZMainThreadMonitor : NSObject

+ (instancetype)shareInstance;
- (void)startMonitor;

@property (nonatomic, weak) id<JZMainThreadMonitorDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
