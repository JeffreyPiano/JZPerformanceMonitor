//
//  JZAppFluencyMonitor.h
//  性能监控
//
//  Created by tutu on 2021/7/10.
//  Copyright © 2021 tutu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface JZAppFluencyMonitor : NSObject
+ (instancetype)monitor;
- (void)startMonitor;
- (void)stopMonitor;
@end

NS_ASSUME_NONNULL_END
