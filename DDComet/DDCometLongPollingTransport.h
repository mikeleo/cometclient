
#import <Foundation/Foundation.h>


@class DDCometClient;

@protocol DDCometLongPollingTransport <NSObject>

- (id)initWithClient:(DDCometClient *)client;
- (void)start;
- (void)cancel;

@end
