
#import <Foundation/Foundation.h>


@class DDCometClient;

@interface DDCometAFLongPollingTransport : NSObject

- (id)initWithClient:(DDCometClient *)client;
- (void)start;
- (void)cancel;

@end
