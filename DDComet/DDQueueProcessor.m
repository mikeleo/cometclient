
#import "DDQueueProcessor.h"
#import <objc/message.h>


@interface DDQueueProcessor ()

@property (nonatomic, strong) NSOperationQueue * operationQueue;

@end

@implementation DDQueueProcessor

- (id)initWithDelegate:(id<DDQueueProcessorDelegate>)delegate
{
    self = [super init];
    if (self)
        {
        self.delegate = delegate;
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.maxConcurrentOperationCount = 1;
        }
    return self;
}


- (void)queueDidAddObject:(id<DDQueue>)queue
{
    typeof(self) weakSelf = self;
    [self.operationQueue addOperationWithBlock:^{
        typeof(weakSelf) strongSelf = weakSelf;
        
        if ([strongSelf.delegate respondsToSelector:@selector(processIncomingMessages)])
            {
            dispatch_async([self.delegate dispatchQueue] ? [self.delegate dispatchQueue] : dispatch_get_main_queue(), ^{
                [strongSelf.delegate processIncomingMessages];
            });
            }
    }];
}


@end
