//
//  DDCometWebSecontTransport.h
//  CometClient
//
//  Created by Michael Leo on 6/25/15.
//
//

#import <Foundation/Foundation.h>
#import "DDCometLongPollingTransport.h"
#import "DDQueue.h"

@interface DDCometWebSocketTransport : NSObject <DDCometLongPollingTransport, DDQueueDelegate>

@end
