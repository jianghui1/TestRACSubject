//
//  TestRACSubjectTests.m
//  TestRACSubjectTests
//
//  Created by ys on 2018/8/23.
//  Copyright © 2018年 ys. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <ReactiveCocoa.h>

@interface TestRACSubjectTests : XCTestCase

@end

@implementation TestRACSubjectTests

- (void)testSubscriber
{
    RACSignal *signal1 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@(1)];
        return nil;
    }];
    RACSignal *signal2 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@(2)];
        return nil;
    }];
    
    RACSubject *subject = [RACSubject subject];
    [subject subscribeNext:^(id x) {
        NSLog(@"subject -- 1 -- %@", x);
    }];
    
    [signal1 subscribe:subject];
    
    [subject subscribeNext:^(id x) {
        NSLog(@"subject -- 2 -- %@", x);
    }];
    
    [signal2 subscribe:subject];
    
    [subject subscribeNext:^(id x) {
        NSLog(@"subject -- 3 -- %@", x);
    }];
    
    // 打印日志：
    /*
     2018-08-24 20:28:07.479248+0800 TestRACSubject[56542:1446617] subject -- 1 -- 1
     2018-08-24 20:28:07.479692+0800 TestRACSubject[56542:1446617] subject -- 1 -- 2
     2018-08-24 20:28:07.479819+0800 TestRACSubject[56542:1446617] subject -- 2 -- 2
     */
}

- (void)testSubscriber1
{
    RACSignal *signal1 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@(1)];
        [subscriber sendCompleted];
        
        return nil;
    }];
    
    RACSignal *signal2 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@(2)];
        [subscriber sendError:nil];
        
        return nil;
    }];
    
    RACSubject *subject = [RACSubject subject];
    
    [subject subscribeNext:^(id x) {
        NSLog(@"subscriber1 -- 1 -- %@", x);
    } error:^(NSError *error) {
        NSLog(@"subscriber1 -- 1 -- error");
    } completed:^{
        NSLog(@"subscriber1 -- 1 -- completed");
    }];
    
    [signal1 subscribe:subject];
    
    [subject subscribeNext:^(id x) {
        NSLog(@"subscriber1 -- 2 -- %@", x);
    } error:^(NSError *error) {
        NSLog(@"subscriber1 -- 2 -- error");
    } completed:^{
        NSLog(@"subscriber1 -- 2 -- completed");
    }];
    
    [signal2 subscribe:subject];
    
    [subject subscribeNext:^(id x) {
        NSLog(@"subscriber1 -- 3 -- %@", x);
    } error:^(NSError *error) {
        NSLog(@"subscriber1 -- 3 -- error");
    } completed:^{
        NSLog(@"subscriber1 -- 3 -- completed");
    }];
    
    // 打印日志：
    /*
     2018-08-24 20:34:59.468280+0800 TestRACSubject[56789:1466595] subscriber1 -- 1 -- 1
     2018-08-24 20:34:59.469266+0800 TestRACSubject[56789:1466595] subscriber1 -- 1 -- completed
     */
}

- (void)testDisposable
{
    RACSignal *signal1 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@(1)];
        return [RACDisposable disposableWithBlock:^{
            NSLog(@"disposable -- signal1");
        }];
    }];
    RACSignal *signal2 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@(2)];
        return [RACDisposable disposableWithBlock:^{
            NSLog(@"disposable -- signal2");
        }];
    }];
    
    RACSubject *subject1 = [RACSubject subject];
    RACDisposable *disposable = [subject1 subscribeNext:^(id x) {
        NSLog(@"subject1 -- %@", x);
    }];
    [disposable dispose];
    
    RACSubject *subject2 = [RACSubject subject];
    [subject2 subscribeNext:^(id x) {
        NSLog(@"subject2 -- %@", x);
    }];
    
    [signal1 subscribe:subject1];
    [signal2 subscribe:subject2];
    
    // 打印日志：
    /*
     2018-08-23 17:59:41.926263+0800 TestRACSubject[39011:1919016] subject2 -- 2
     2018-08-23 17:59:41.926459+0800 TestRACSubject[39011:1919016] disposable -- signal2
     2018-08-23 17:59:41.926606+0800 TestRACSubject[39011:1919016] disposable -- signal1
     */
}

@end
