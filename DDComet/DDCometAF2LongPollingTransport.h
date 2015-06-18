
#import <Foundation/Foundation.h>


@class DDCometClient;

@interface DDCometAF2LongPollingTransport : NSObject

- (id)initWithClient:(DDCometClient *)client;
- (void)start;
- (void)cancel;

@end
