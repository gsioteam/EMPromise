# EMPromise
A promise framework for Objective-C.

## Usage

Just like JavScript Promise.

```objc
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
```

## Catch Exception

```objc
[EMPromise promise:^(promise_resolve_block  _Nonnull resolve, promise_reject_block  _Nonnull reject) {
    @throw [NSException exceptionWithName:@"Test"
                                    reason:@"test"
                                  userInfo:nil];
}].catchError(^(NSError *error) {
    NSLog(@"catch %@", error);
});
```

## Timeout

```objc
[EMPromise promise:^(promise_resolve_block  _Nonnull resolve, promise_reject_block  _Nonnull reject) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        resolve(@(0));
    });
}].timeout(10).then(^id _Nullable(id  _Nullable result) {
    NSLog(@"result %@", result);
    return nil;
}).catchError(^(NSError *error) {
    NSLog(@"error %@", error);
});
```

## Iterator

Iterate a array. 

```objc
[EMPromise forEach:arr block:^(id  _Nonnull obj, NSUInteger idx, id  _Nonnull lastResult, promise_resolve_block  _Nonnull resolve, promise_reject_block  _Nonnull reject) {
    NSInteger sum = [lastResult integerValue] + [obj integerValue];
    NSLog(@"sum : %d", (int)sum);
    resolve(@(sum));
}].then(^id _Nullable(id  _Nullable result) {
    NSLog(@"result: %@", result);
    return nil;
});

```

`forEach` function only alloc one Promise object, the efficiency is 10x faster than the efficiency of iterating by `then` function.

## Synchronized Task

If the task is synchronized, you can get result synchronously. 
That means you do not need to worry about the promise would delay the task.

```objc
__block id syncResult;
[EMPromise promise:^(promise_resolve_block  _Nonnull resolve, promise_reject_block  _Nonnull reject) {
    resolve(@"hello");
}].then(^id _Nullable(id  _Nullable result) {
    syncResult = result;
    return nil;
});
NSLog(@"%@", syncResult);

[EMPromise forEach:arr
              block:^(id  _Nonnull obj, NSUInteger idx, id  _Nonnull lastResult, promise_resolve_block  _Nonnull resolve, promise_reject_block  _Nonnull reject) {
    resolve(@([lastResult integerValue] + [obj integerValue]));
}].then(^id _Nullable(id  _Nullable result) {
    syncResult = result;
    return nil;
});
NSLog(@"%@", syncResult);
```