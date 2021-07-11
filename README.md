# JZPerformanceMonitor
# 卡顿监控

> 苹果手机每秒显示是 60 帧画面，也就是说 16ms 的间隔就需要展示一帧的图片，如果一秒内展示的少于 50 帧画面，那用户就会感觉到明显的卡顿。只有当屏幕刷新频率足够高，画面看起来才会是连续且流畅的，FPS 是屏幕的刷新频率，App 应该保持 60FPS 才是最好的体验。

**屏幕成像**

- 图像的显示离不开 CPU 与 GPU 的分工合作，CPU 主要是对图像渲染的控制，计算图片的 frame，并将要解码的图片数据通过数据总线交给 GPU。GPU 接下来就会对图片顶点数据进行下列操作：
  - 顶点着色器是将顶点坐标转换，增加光照信息等
  - 形状装配是将顶点进行连接成对应的形状
  - 几何着色器是将原始图元转换为更加复杂的几何图形
  - 光栅化将图元信息转换为像素信息
  - 后面 2 个阶段则是将像素信息渲染成对应的位图
  
    ![](https://files.mdnice.com/user/8695/a60865e5-3e24-432c-b5aa-c25e2cdc866c.png)

**显示与卡顿**

- GPU 将渲染得到的位图缓存到帧缓冲区中，视频控制器会将帧缓冲区中的数据进行获取，经过数模转换最终显示到屏幕上。GPU 不断地渲染图片，并将得到的位图信息进行缓存，电子束不断地对位图信息进行扫描，位图在屏幕上不断显示出来，为了不出现屏幕撕裂，即电子数扫描新的一帧时，位图还没有渲染好，等到扫描到中间时，图片才渲染完成，这时屏幕上半部分就会显示上一张图片，下半部分就会显示新的一张图片，导致出现屏幕撕裂。
- 苹果爸爸解决屏幕撕裂的问题就是使用垂直同步信号和双缓冲机制，垂直同步信息就是等到电子束扫描完成才进行下一帧的扫描，双缓冲机制是提前将图片渲染到备用缓冲区中。
- 卡顿的原因就是掉帧，由于图片渲染时间过长，帧缓冲区中拿不到最新的位图数据，此时屏幕会显示上一帧的内容，导致出现卡顿。

**监控卡顿**

1.  YYFPSLabel

```objectivec
@implementation YYFPSLabel {
  CADisplayLink *_link;
  NSUInteger _count;
  NSTimeInterval _lastTime;
  UIFont *_font;
  UIFont *_subFont;

  NSTimeInterval _llll;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (frame.size.width == 0 && frame.size.height == 0) {
      frame.size = kSize;
  }
  self = [super initWithFrame:frame];
  //省略部分代码
  _link = [CADisplayLink displayLinkWithTarget:[YYWeakProxy proxyWithTarget:self] selector:@selector(tick:)];
  [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
  return self;
}

- (void)dealloc {
  //调用invalidate后_link会从runloop中移除
  [_link invalidate];
}

- (void)tick:(CADisplayLink *)link {
  if (_lastTime == 0) {
      _lastTime = link.timestamp;
      return;
  }

  _count++;
  //计算上一帧与下一帧之间的耗时
  NSTimeInterval delta = link.timestamp - _lastTime;
  if (delta < 1) return;
  _lastTime = link.timestamp;
  float fps = _count / delta;
  _count = 0;

  CGFloat progress = fps / 60.0;
  UIColor *color = [UIColor colorWithHue:0.27 * (progress - 0.2) saturation:1 brightness:0.9 alpha:1];
      NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d FPS",(int)round(fps)]];
  [text setColor:color range:NSMakeRange(0, text.length - 3)];
  [text setColor:[UIColor whiteColor] range:NSMakeRange(text.length - 3, 3)];
  text.font = _font;
  [text setFont:_subFont range:NSMakeRange(text.length - 4, 1)];
  self.attributedText = text;
}

@end
```

- 使用了 CADisplayLink 对 App 的主线程进行实时监控，让我们可以知道主线程是否存在卡顿，但是 YYFPSLabel 在 CPU 层面进行了监控，但是 FPS 其实还包括了 GPU 的处理情况，所以 YYFPSLabel 并不难准确地进行判断卡顿问题。
- 将 CADisplayLink 添加到主线程的 runloop 中进行监控，获取上一帧与下一帧的时间，以此来判断哪里出现了耗时。
- **当然 CADisplayLink 会存在强引用着对象，所以一般使用 CADisplayLink 会生成一个中间对象来弱引用着当前对象，才会导致 CADisplayLink 销毁时当前对象能够被释放，防止内存泄露问题。**

2. JZMainThreadMonitor

```objectivec
 - (void)startWatch {

  if ([NSThread isMainThread] == false) {
      NSLog(@"Error: startWatch must be called from main thread!");
      return;
  }

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(detectPingFromWorkerThread) name:Notification_PMainThreadWatcher_Worker_Ping object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(detectPongFromMainThread) name:Notification_PMainThreadWatcher_Main_Pong object:nil];

  install_signal_handler();

  mainThreadID = pthread_self();

  //ping from worker thread
  uint64_t interval = PMainThreadWatcher_Watch_Interval * NSEC_PER_SEC;
  self.pingTimer = createGCDTimer(interval, interval / 10000, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [self pingMainThread];
  });
}

- (void)pingMainThread
{
  //每16毫秒执行一帧
  uint64_t interval = PMainThreadWatcher_Warning_Level * NSEC_PER_SEC;
  self.pongTimer = createGCDTimer(interval, interval / 10000, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [self onPongTimeout];
  });

  //如果主线程卡顿时，会影响发送通知，这时就会执行上面的onPongTimeout回调主线程超时
  dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter] postNotificationName:Notification_PMainThreadWatcher_Worker_Ping object:nil];
  });
}

- (void)detectPingFromWorkerThread
{
  [[NSNotificationCenter defaultCenter] postNotificationName:Notification_PMainThreadWatcher_Main_Pong object:nil];
}

- (void)onPongTimeout
{
  [self cancelPongTimer];
  printMainThreadCallStack();
}

- (void)detectPongFromMainThread
{
  [self cancelPongTimer];
}

- (void)cancelPongTimer
{
  if (self.pongTimer) {
      dispatch_source_cancel(_pongTimer);
      _pongTimer = nil;
  }
}
```

- 通过 GCD 计时器进行卡顿监控，pingTimer 计时器进行每秒监控主线程卡顿，pongTimer 计时器则是判断当前任务执行是否超过 16ms，造成耗时。
- 当监控到主线程卡顿时，会发出一个 BSD signal 信号，这个信号会中断主线程对这个信号进行回调处理后，如果在调试阶段会定位出现造成耗时卡顿的代码位置。

3. 通过监控主线程 RunLoop 卡顿

```objectivec
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
```

- 通过监控主线程的 RunLoop 状态是 kCFRunLoopBeforeSources 或 kCFRunLoopAfterWaiting 的情况下，是否出现 N 次卡顿超过阈值，如果是则判断为出现了卡顿。

4. 通过 ping 主线程监控卡顿

```objectivec
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
```

- 通过子线程 ping 主线程判断主线程是否在 50 毫秒内阻塞了，如果主线程能在 50 毫秒做出响应，证明主线程没被阻塞。

参考资料：
[PMainThreadWatcher](https://github.com/music4kid/PMainThreadWatcher)

