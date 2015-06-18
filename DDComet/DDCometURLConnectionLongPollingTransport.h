
#import <Foundation/Foundation.h>
#import "DDCometLongPollingTransport.h"

@class DDCometClient;

@interface DDCometURLConnectionLongPollingTransport : NSObject <DDCometLongPollingTransport>
{
@private
	DDCometClient *m_client;
	volatile BOOL m_shouldCancel;
}

@end
