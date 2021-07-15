//
//  Promise.m
//  Promise
//
//  Created by gen on 7/14/21.
//

#import "EMPromise.h"

typedef enum {
    Running,
    Resolved,
    Rejected
} PromiseState;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wimplicit-retain-self"

@implementation EMTimeoutError

- (id)init {
    self = [super initWithDomain:@"Timeout" code:1005
                        userInfo:nil];
    return self;
}

@end

@implementation EMExceptionError

- (id)initWithException:(NSException *)exception {
    self = [super initWithDomain:exception.name
                            code:1009
                        userInfo:@{
                            @"exception": exception
                        }];
    return self;
}

@end

@interface EMTimeout : NSObject

@property (nonatomic, strong) EMTimeout *selfRef;
@property (nonatomic, copy) dispatch_block_t block;

+ (instancetype)timeoutWithDelay:(NSTimeInterval)delay block:(dispatch_block_t)block queue:(dispatch_queue_t)queue;
- (void)cancel;

@end

@implementation EMTimeout {
    BOOL _canceled;
}

+ (instancetype)timeoutWithDelay:(NSTimeInterval)delay block:(dispatch_block_t)block queue:(dispatch_queue_t)queue {
    EMTimeout *timeout = [[EMTimeout alloc] init];
    timeout.block = block;
    __weak EMTimeout *that = timeout;
    timeout.selfRef = timeout;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), queue, ^{
        [that fire];
    });
    return timeout;
}

- (void)cancel {
    _canceled = YES;
    self.selfRef = nil;
}

- (void)fire {
    self.selfRef = nil;
    if (!_canceled) self.block();
}

@end

typedef void(^promise_result_block)(PromiseState state, id _Nullable result);

@interface EMPromise()

@property (nonatomic, assign) PromiseState state;
// To retain self when task is running.
@property (nonatomic, strong) EMPromise *selfRef;
@property (nonatomic, strong) id result;
@property (nonatomic, strong) NSMutableArray<promise_result_block> *callbacks;
@property (nonatomic, strong) EMTimeout *timeoutHandler;

@end

@interface EMForPromise : EMPromise

@property (nonatomic, strong) NSArray *array;
@property (nonatomic, copy) promise_for_each_block  block;

@property (atomic, assign) BOOL canceled;

@end

@implementation EMForPromise {
    NSInteger _index;
    id _lastResult;
}

- (void)run {
    _index = 0;
    self.canceled = NO;
    [self next];
}

- (void)next {
    if (_index < self.array.count) {
        while (true) {
            if (self.canceled) return;
            __block BOOL complete = NO;
            __block BOOL async = NO;
            id obj = [self.array objectAtIndex:_index];
            self.block(obj, _index, _lastResult, ^(id  _Nullable result) {
                complete = true;
                ++_index;
                _lastResult = result;
                if (async) {
                    if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(self.queue)) == 0) {
                        [self next];
                    } else {
                        dispatch_async(self.queue, ^{
                            [self next];
                        });
                    }
                }
            }, ^(NSError * _Nonnull error) {
                [self rejectWithError:error];
            });
            if (complete) {
                if (_index >= self.array.count) {
                    [self resolveWithResult:_lastResult];
                    return;
                }
            } else {
                async = YES;
                break;
            }
        }
    } else {
        [self resolveWithResult:_lastResult];
    }
}

- (void)clean {
    self.canceled = YES;
}

@end

@interface EMBlockPromise : EMPromise

@property (nonatomic, copy) promise_block block;

@end

@implementation EMBlockPromise

- (void)run {
    __weak EMBlockPromise *that = self;
    [self async:^{
        @try {
            that.block(^(id result) {
                [that resolveWithResult:result];
            }, ^(NSError *error) {
                [that rejectWithError:error];
            });
        } @catch (NSException *exception) {
            [that rejectWithError:[[EMExceptionError alloc] initWithException:exception]];
        }
    }];
}

@end

@interface EMTimeoutPromise : EMPromise

@property (nonatomic, assign) NSTimeInterval wait;

@end

@implementation EMTimeoutPromise

- (void)run {
    __weak EMTimeoutPromise *that = self;
    
    self.selfRef = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.wait * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [that resolveWithResult:nil];
    });
}

@end

@implementation EMPromise

- (id)initWithQueue:(dispatch_queue_t)queue {
    self = [super init];
    if (self) {
//        NSLog(@"init %@", self);
        _state = Running;
        _callbacks = [NSMutableArray array];
        _queue = queue;
    }
    return self;
}

- (void)run {}
- (void)clean {}

- (void)start {
    self.selfRef = self;
    [self run];
}

- (void)checkStart {
    if (self.selfRef == nil && self.state == Running) {
        [self start];
    }
}

- (EMPromise *)ready {
    [self checkStart];
    return self;
}

+ (instancetype)promise:(promise_block)block {
    return [self promise:block queue:dispatch_get_main_queue()];
}

+ (instancetype)promise:(promise_block)block queue:(dispatch_queue_t)queue {
    EMBlockPromise *promise = [[EMBlockPromise alloc] initWithQueue:queue];
    promise.block = block;
    return promise.ready;
}

+ (instancetype)wait:(NSTimeInterval)time {
    return [self wait:time queue:dispatch_get_main_queue()];
}

+ (instancetype)wait:(NSTimeInterval)time queue:(nonnull dispatch_queue_t)queue {
    EMTimeoutPromise *promise = [[EMTimeoutPromise alloc] initWithQueue:queue];
    promise.wait = time;
    return promise.ready;
}

+ (instancetype)resolve:(id)result {
    return [self resolve:result queue:dispatch_get_main_queue()];
}

+ (instancetype)resolve:(id)result queue:(dispatch_queue_t)queue {
    EMPromise *promise = [[self alloc] initWithQueue:queue];
    promise.state = Resolved;
    promise.result = result;
    return promise.ready;
}

+ (instancetype)reject:(NSError *)error {
    return [self reject:error queue:dispatch_get_main_queue()];
}

+ (instancetype)reject:(NSError *)error queue:(dispatch_queue_t)queue {
    EMPromise *promise = [[self alloc] initWithQueue:queue];
    promise.state = Rejected;
    promise.result = error;
    return promise.ready;
}

+ (instancetype)forEach:(NSArray *)array block:(promise_for_each_block)block {
    return [self forEach:array
                   block:block
                   queue:dispatch_get_main_queue()];
}

+ (instancetype)forEach:(NSArray *)array block:(promise_for_each_block)block queue:(dispatch_queue_t)queue {
    if (array.count > 0) {
        EMForPromise *promise = [[EMForPromise alloc] initWithQueue:queue];
        promise.array = array;
        promise.block = block;
        return promise.ready;
    } else {
        return [self resolve:nil];
    }
}

- (void)async:(dispatch_block_t)block {
    if (strcmp(dispatch_queue_get_label(_queue), dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL)) == 0) {
        block();
    } else {
        dispatch_async(_queue, block);
    }
}

- (void)overWithState:(PromiseState)state withObject:(id)object {
    [self async:^{
        if (_state == Running) {
            _selfRef = nil;
            _state = state;
            if (state == Resolved) {
                @try {
                    _result = object;
                    for (promise_result_block block in _callbacks)
                        block(_state, _result);
                } @catch (NSException *e) {
                    _state = Rejected;
                    _result = [[EMExceptionError alloc] initWithException:e];
                    for (promise_result_block block in _callbacks)
                        block(_state, _result);
                }
            } else {
                _result = object;
                for (promise_result_block block in _callbacks)
                    block(_state, _result);
            }
            [_callbacks removeAllObjects];
            [self.timeoutHandler cancel];
            self.timeoutHandler = nil;
            [self clean];
        }
    }];
}

- (void)resolveWithResult:(id)result {
    if ([result isKindOfClass:EMPromise.class]) {
        [self runPromise:result];
    } else {
        [self overWithState:Resolved withObject:result];
    }
}

- (void)rejectWithError:(NSError *)error {
    [self overWithState:Rejected withObject:error];
}

- (void)runPromise:(EMPromise *)promise {
    __weak EMPromise *that = self;
    [self async:^{
        if (that.state == Running) {
            [promise innerThen:^(id  _Nonnull result) {
                [that resolveWithResult:result];
            }];
            [promise catchError:^(NSError * _Nonnull error) {
                [that overWithState:Rejected withObject:error];
            }];
        }
    }];
}

- (void)innerThen:(promise_resolve_block)block {
    [self async:^{
        switch (_state) {
            case Running:
            {
                [_callbacks addObject:^(PromiseState state, id result) {
                    if (state == Resolved) block(result);
                }];
            }
                break;
            case Resolved:
                block(_result);
                break;
                
            default:
                break;
        }
    }];
}

- (promise_then_block)then {
    __weak EMPromise *that = self;
    return ^(promise_then_handler block) {
        return [that then:block];
    };
}

- (EMPromise *)then:(promise_then_handler)block {
    // Start the task if ready not called.
    [self checkStart];
    return [EMPromise promise:^(promise_resolve_block  _Nonnull resolve, promise_reject_block  _Nonnull reject) {
        [self innerThen:^(id  _Nullable result) {
            resolve(block(result));
        }];
        [self catchError:^(NSError * _Nonnull error) {
            reject(error);
        }];
    } queue:_queue];
}

- (promise_catch_block)catchError {
    __weak EMPromise *that = self;
    return ^(promise_reject_block block) {
        return [that catchError:block];
    };
}

- (EMPromise *)catchError:(promise_reject_block)block {
    // Start the task if ready not called.
    [self checkStart];
    [self async:^{
        switch (_state) {
            case Running:
            {
                [_callbacks addObject:^(PromiseState state, id result) {
                    if (state == Rejected) block(result);
                }];
            }
                break;
            case Rejected:
                block(_result);
                break;
                
            default:
                break;
        }
    }];
    return self;
}

- (promise_timeout_block)timeout {
    __weak EMPromise *that = self;
    return ^(NSTimeInterval timeout) {
        return [that timeout:timeout];
    };
}

- (EMPromise *)timeout:(NSTimeInterval)timeout {
    // Start the task if ready not called.
    [self checkStart];
    [self.timeoutHandler cancel];
    __weak EMPromise *that = self;
    self.timeoutHandler = [EMTimeout timeoutWithDelay:timeout
                                                block:^{
        [that rejectWithError:[EMTimeoutError new]];
    } queue:_queue];
    return self;
}

//- (void)dealloc {
//    NSLog(@"dealloc %@", self);
//}

@end

#pragma clang diagnostic pop
