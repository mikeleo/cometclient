
#import <Foundation/Foundation.h>
#import "DDQueue.h"

@protocol DDQueueProcessorDelegate <NSObject>

- (dispatch_queue_t) dispatchQueue;

- (void) processIncomingMessages;

@end

@interface DDQueueProcessor : NSObject <DDQueueDelegate>

@property (nonatomic, weak) id<DDQueueProcessorDelegate> delegate;

- (id)initWithDelegate:(id<DDQueueProcessorDelegate>) delegate;

@end
