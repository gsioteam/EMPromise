//
//  AppDelegate.m
//  Promise
//
//  Created by gen on 7/14/21.
//

#import "AppDelegate.h"
#import "EMPromise.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    dispatch_queue_t queue = dispatch_queue_create("test_queue", NULL);
    
    [EMPromise promise:^(promise_resolve_block  _Nonnull resolve, promise_reject_block  _Nonnull reject) {
        NSLog(@"1 %s", dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
        resolve([EMPromise wait:5]);
    } queue:queue].then(^(id result) {
        NSLog(@"2 %s", dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
        return [EMPromise wait:5];
    }).then(^(id result) {
        NSLog(@"3 %s", dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
        return [EMPromise wait:5];
    }).then(^(id result) {
        NSLog(@"4 %s", dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
        @throw [NSException exceptionWithName:@"Test"
                                       reason:@"test"
                                     userInfo:nil];
        return [EMPromise wait:5];
    }).then(^(id result) {
        NSLog(@"5 %s", dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
        return [EMPromise wait:5];
    }).then(^id(id result) {
        NSLog(@"6 %s", dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
        return nil;
    }).catchError(^(NSError *error) {
        NSLog(@"catch %@ %s", error, dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
    });
    
    NSMutableArray *arr = [NSMutableArray array];
    for (NSInteger i = 0; i < 10000; ++i) {
        [arr addObject:@(i)];
    }
    
    NSTimeInterval _old = [NSDate date].timeIntervalSince1970;
    [EMPromise forEach:arr block:^(id  _Nonnull obj, NSUInteger idx, id  _Nonnull lastResult, promise_resolve_block  _Nonnull resolve, promise_reject_block  _Nonnull reject) {
        resolve(@([lastResult integerValue] + [obj integerValue]));
    }].then(^id _Nullable(id  _Nullable result) {
        NSLog(@"result: %@", result);
        return nil;
    }).catchError(^(NSError *error) {
        NSLog(@"error %@", error);
    });
    
//    __block NSNumber *sum = @(0);
//    void (^block)(NSNumber *i) = ^(NSNumber *i){
//        sum = @(i.integerValue + sum.integerValue);
//    };
//    for (NSInteger i = 0; i < arr.count; ++i) {
//        block(arr[i]);
//    }
//    NSLog(@"result: %@", sum);
    
    NSLog(@"Using: %f", [NSDate date].timeIntervalSince1970 - _old);
    
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
}


@end
