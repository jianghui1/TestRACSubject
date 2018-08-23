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
        NSLog(@"subject -- %@", x);
    }];
    
    [signal1 subscribe:subject];
    [signal2 subscribe:subject];
    
    // 打印日志：
    /*
     2018-08-23 17:53:39.399263+0800 TestRACSubject[38753:1900945] subject -- 1
     2018-08-23 17:53:39.399481+0800 TestRACSubject[38753:1900945] subject -- 2
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
