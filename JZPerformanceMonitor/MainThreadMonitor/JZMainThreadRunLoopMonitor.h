//
//  JZMainThreadRunLoopMonitor.h
//  性能监控
//
//  Created by tutu on 2021/7/10.
//  Copyright © 2021 tutu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JZMainThreadRunLoopMonitor : NSObject
+ (instancetype)monitor;
- (void)startMonitor;
@end

NS_ASSUME_NONNULL_END
