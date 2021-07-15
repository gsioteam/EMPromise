//
//  Promise.h
//  Promise
//
//  Created by gen on 7/14/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMTimeoutError : NSError

@end

@interface EMExceptionError : NSError

- (id)initWithException:(NSException *)exception;

@end

@class EMPromise;

typedef void(^promise_resolve_block)(id _Nullable result);
typedef void(^promise_reject_block)(NSError *error);
typedef void(^promise_block)(promise_resolve_block resolve, promise_reject_block reject);

typedef id _Nullable (^promise_then_handler)(id _Nullable result);

typedef EMPromise*_Nonnull(^promise_then_block)(promise_then_handler block);
typedef EMPromise*_Nonnull(^promise_catch_block)(promise_reject_block block);
typedef EMPromise*_Nonnull(^promise_timeout_block)(NSTimeInterval timeout);

@interface EMPromise : NSObject

@property (nonatomic, readonly) dispatch_queue_t queue;
/**
 * return a new Promise
 */
@property (nonatomic, readonly) promise_then_block then;
/**
 * return self
 */
@property (nonatomic, readonly) promise_catch_block catchError;
@property (nonatomic, readonly) promise_timeout_block timeout;
/**
 * Call ready after all arguments ready.
 * reutn self
 */
@property (nonatomic, readonly) EMPromise *ready;

- (EMPromise *)then:(promise_then_handler)block;
- (EMPromise *)catchError:(promise_reject_block)block;

/**
 * Timeout return self, that means each promise could have a timer.
 * And promise could cancel its task instantly to avoid wasting resources when timeout.
 */
- (EMPromise *)timeout:(NSTimeInterval)timeout;

@end

@interface EMPromise (Override)

- (id)initWithQueue:(dispatch_queue_t)queue;
/**
 * Start run this promise
 */
- (void)run;
/**
 * A good place to stop task
 */
- (void)clean;

@end

@interface EMPromise (Protect)

/**
 * If the dispatch queue is activing, run block directly, otherwise async run block on the dispatch queue.
 */
- (void)async:(dispatch_block_t)block;

/**
 * Set the task result
 */
- (void)resolveWithResult:(id _Nullable)result;
- (void)rejectWithError:(NSError *)error;

@end

typedef void(^promise_for_each_block)(id  _Nonnull obj, NSUInteger idx, id lastResult, promise_resolve_block resolve, promise_reject_block reject);

@interface EMPromise (ExtensionConstructors)

+ (instancetype)resolve:(id _Nullable)result;
+ (instancetype)resolve:(id _Nullable)result queue:(dispatch_queue_t)queue;
+ (instancetype)reject:(NSError *)error;
+ (instancetype)reject:(NSError *)error queue:(dispatch_queue_t)queue;

+ (EMPromise *)promise:(promise_block)block;
+ (EMPromise *)promise:(promise_block)block queue:(dispatch_queue_t)queue;

+ (EMPromise *)wait:(NSTimeInterval)time;
+ (EMPromise *)wait:(NSTimeInterval)time queue:(dispatch_queue_t)queue;

+ (EMPromise *)forEach:(NSArray * _Nullable)array block:(promise_for_each_block)block;
+ (EMPromise *)forEach:(NSArray * _Nullable)array block:(promise_for_each_block)block queue:(dispatch_queue_t)queue;

@end

NS_ASSUME_NONNULL_END
