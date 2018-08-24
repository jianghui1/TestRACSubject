##### `RACSubject`作为`RACSignal`的子类，也遵循了`RACSubscriber`协议，而且如果对信号有所了解，应该知道`RACSubject`就是热信号。接下来就分析下`RACSubject`的源码。

首先，看下`.h`文件。里面有关于这个类的注释：

    /// A subject can be thought of as a signal that you can manually control by
    /// sending next, completed, and error.
    ///
    /// They're most helpful in bridging the non-RAC world to RAC, since they let you
    /// manually control the sending of events.
翻译如下：

    一个`subject`对象可以被当做一个可以手动发送`next` `completed` `error` 事件的信号。
    
    由于可以手动控制信号事件的发送，所以该类在桥接 非rac 与 rac 时，非常有帮助。

接着提供了一个`+ (instancetype)subject;`方法，用于实例化对象。

***
其实，`.h`中的信息还是非常少的，现在打开`.m`文件，分析具体实现逻辑。

    + (instancetype)subject {
    	return [[self alloc] init];
    }
调用`alloc` `init` 完成初始化操作。

    - (id)init {
    	self = [super init];
    	if (self == nil) return nil;
    
    	_disposable = [RACCompoundDisposable compoundDisposable];
    	_subscribers = [[NSMutableArray alloc] initWithCapacity:1];
    	
    	return self;
    }
重写`init`方法，同时完成实例变量的初始化工作。注意`_disposable`是`RACCompoundDisposable`类型，`_subscribers`是`NSMutableArray`类型。

    - (void)dealloc {
    	[self.disposable dispose];
    }
重写`dealloc`方法，最终调用清理对象的清理方法完成清理工作。

    - (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    	NSCParameterAssert(subscriber != nil);
    
    	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
    	subscriber = [[RACPassthroughSubscriber alloc] initWithSubscriber:subscriber signal:self disposable:disposable];
    
    	NSMutableArray *subscribers = self.subscribers;
    	@synchronized (subscribers) {
    		[subscribers addObject:subscriber];
    	}
    	
    	return [RACDisposable disposableWithBlock:^{
    		@synchronized (subscribers) {
    			// Since newer subscribers are generally shorter-lived, search
    			// starting from the end of the list.
    			NSUInteger index = [subscribers indexOfObjectWithOptions:NSEnumerationReverse passingTest:^ BOOL (id<RACSubscriber> obj, NSUInteger index, BOOL *stop) {
    				return obj == subscriber;
    			}];
    
    			if (index != NSNotFound) [subscribers removeObjectAtIndex:index];
    		}
    	}];
    }
重写信号的订阅方法，前面几步跟`RACDynamicSignal`还是比较像的，后面的步骤会有些差别。同样的，还是分步骤分析：
1. 初始化一个`RACCompoundDisposable`对象。
2. 重新将`subscriber`初始化为`RACPassthroughSubscriber`类型。
3. 将`subscriber`添加的数组`subscribers`当中。
4. 返回一个清理对象，这个清理对象的清理任务就是将`subscriber`从`subscribers`中移除。


    - (void)enumerateSubscribersUsingBlock:(void (^)(id<RACSubscriber> subscriber))block {
    	NSArray *subscribers;
    	@synchronized (self.subscribers) {
    		subscribers = [self.subscribers copy];
    	}
    
    	for (id<RACSubscriber> subscriber in subscribers) {
    		block(subscriber);
    	}
    }
该类的私有方法，遍历数组`subscribers`拿到`subscriber`对象，然后将`subscriber`作为`block`的参数完成`block`的调用。

    - (void)sendNext:(id)value {
    	[self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
    		[subscriber sendNext:value];
    	}];
    }
实现`subscriber`协议的方法，通过私有方法`enumerateSubscribersUsingBlock:`使保存的所有`subscriber`对象调用`sendNext:`方法完成信号值的发送。

    - (void)sendError:(NSError *)error {
    	[self.disposable dispose];
    	
    	[self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
    		[subscriber sendError:error];
    	}];
    }
实现`subscriber`协议的方法，先调用清理对象的清理方法；然后通过私有方法`enumerateSubscribersUsingBlock:`使保存的所有`subscriber`对象调用`sendError`方法完成错误信息的发送。

    - (void)sendCompleted {
    	[self.disposable dispose];
    	
    	[self enumerateSubscribersUsingBlock:^(id<RACSubscriber> subscriber) {
    		[subscriber sendCompleted];
    	}];
    }
实现`subscriber`协议的方法，先调用清理对象的清理方法；然后通过私有方法`enumerateSubscribersUsingBlock:`使保存的所有`subscriber`对象调用`sendCompleted`方法发送完成信息。

    - (void)didSubscribeWithDisposable:(RACCompoundDisposable *)d {
    	if (d.disposed) return;
    	[self.disposable addDisposable:d];
    
    	@weakify(self, d);
    	[d addDisposable:[RACDisposable disposableWithBlock:^{
    		@strongify(self, d);
    		[self.disposable removeDisposable:d];
    	}]];
    }
实现`subscriber`协议的方法，与`RACSubscriber`中实现的一样，将`d`添加到`self.disposable`中，同时给`d`添加一个 可以从`self.disposable`中移除的 清理任务。

***
其实，这里主要重写了关于信号订阅和事件发送的方法，使得该类可以同时拥有多个订阅者，并且同时进行多个订阅者的事件发送。

测试用例：

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
***
由于`subscribe:`方法返回的清理对象添加了一个将`subscriber`从`subscribers`移除的清理任务，所以外界如果调用返回的清理对象的清理方法，可以阻止信号事件的发送。同时，就算外部没有显式调用清理对象的清理方法，还是不会影响到清理工作的进行。

测试用例：

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
***
还有就是如果该类的实例对象收到了订阅信号的完成信息或者错误信息，后面就不会再对新的订阅者发送任何事件。

测试用例：

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

上面用到的测试用例在[这里](https://github.com/jianghui1/TestRACSubject)。

以上把`RACSubject`类分析完了，其实他还有一些子类，接下去会先将子类分析完，再去分析其他遵循了`RACSubscriber`协议的类。
