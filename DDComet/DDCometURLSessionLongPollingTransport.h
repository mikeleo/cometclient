
#import <Foundation/Foundation.h>
#import "DDCometLongPollingTransport.h"
#import "DDQueue.h"

@class DDCometClient;

@interface DDCometURLSessionLongPollingTransport : NSObject <DDCometLongPollingTransport, DDQueueDelegate>

@end
