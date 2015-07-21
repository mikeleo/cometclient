//
//  DDCometWebSecontTransport.m
//  CometClient
//
//  Created by Michael Leo on 6/25/15.
//
//

#import "DDCometWebSocketTransport.h"
#import "DDCometClient.h"
#import "DDCometMessage.h"
#import "DDQueue.h"
#import <SocketRocket/SRWebSocket.h>

#define kDefaultConnectionTimeout 60.0
#define kConnectionTimeoutVariance 5
#define kMinPollTime 0.020  // The minimum time between polls in seconds

@interface DDCometWebSocketTransport () <SRWebSocketDelegate>

@property (nonatomic, weak) DDCometClient * cometClient;

@property (nonatomic, strong) SRWebSocket * webSocket;

@property (nonatomic, strong) NSOperationQueue * operationQueue;

/// YES if the client is connected to the realtime service
@property (readonly, getter = isConnected) BOOL connected;

@end

@implementation DDCometWebSocketTransport

- (id)initWithClient:(DDCometClient *)client
{
    if ((self = [super init]))
        {
        if (client != nil)
            {
            _cometClient = client;
            
            [_cometClient addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:nil];
            }
        
        self.operationQueue = [[NSOperationQueue alloc] init];
        
        }
    return self;
}

- (void)dealloc
{
    if (_cometClient != nil)
        {
        @try
            {
            [_cometClient removeObserver:self forKeyPath:@"state"];
            }
        @catch(id anException)
            {
            //do nothing.  It wad previ
            }
        }
}

- (void)start
{
    [self.operationQueue addOperationWithBlock:^{
        [self processMessages];
    }];
}

- (void)cancel
{
    if (_webSocket)
        {
        [_webSocket close];

        _webSocket = nil;
        }
    
    if (_cometClient != nil)
        {
        [_cometClient removeObserver:self forKeyPath:@"state"];
        
        _cometClient = nil;
        }
}

#pragma mark - DDQueueDelegate

- (void)queueDidAddObject:(id<DDQueue>)queue
{
    typeof(self) weakSelf = self;
    [self.operationQueue addOperationWithBlock:^{
        typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf processMessages];
    }];
}

#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"state"])
        {
        DDCometState state = (DDCometState)[(NSNumber *)[change objectForKey:NSKeyValueChangeNewKey] intValue];
        if (state == DDCometStateConnected)
            {
            typeof(self) weakSelf = self;
            [self.operationQueue addOperationWithBlock:^{
                typeof(weakSelf) strongSelf = weakSelf;
                [strongSelf processMessages];
            }];
            [self setupPingTimer];
            }
        }
}

- (void) processMessages
{
    NSMutableArray * messagesList = [NSMutableArray array];
    
    //1. Set up Long Polling if it is required
    NSLog(@"SR State: %ul", _webSocket.readyState);
    if (!_connected)
        {
        [self connectWebSocket];
        return;
        }
    
    if (_cometClient.state == DDCometStateConnected)
        {
        DDCometMessage *message = [DDCometMessage messageWithChannel:@"/meta/connect"];
        message.clientID = _cometClient.clientID;
        message.connectionType = @"websocket";
        NSLog(@"Sending websocket message: %@", message);
        [messagesList addObject:@[message]];
        }
    
    //2. Send additional messages if present
    NSArray *outgoingMessagesList = [self outgoingMessages];
    
    if ([outgoingMessagesList count] > 0)
        {
        [messagesList addObject:outgoingMessagesList];
        }
    
    //3. Send all the messages
    for (NSArray * messages in messagesList)
        {
        
        if ([messages count] != 0)
            {
            for (int i = 0; i < messages.count;i++)
                {
                NSDictionary * message = ((DDCometMessage*)messages[i]).proxyForJson;
                [self writeMessageToWebSocket:message];
                }
            }
        }
}

- (NSArray *)outgoingMessages
{
    NSMutableArray *messages = [NSMutableArray array];
    DDCometMessage *message;
    id<DDQueue> outgoingQueue = [_cometClient outgoingQueue];
    while ((message = [outgoingQueue removeObject]))
        [messages addObject:message];
    return messages;
}


-(NSTimeInterval)timeoutInterval
{
    NSNumber *timeout = (_cometClient.advice)[@"timeout"];
    if (timeout)
        return (([timeout floatValue] / 1000) + kConnectionTimeoutVariance);
    else
        return kDefaultConnectionTimeout;
}

#pragma mark - NSURLConnectionDelegate


- (void)connectionDidFinishWithSuccess:(NSURLSessionDataTask *)task responseObject:(id) responseObject timeStamp:(NSDate *) timeStamp messages:(NSArray *) messages
{
    NSArray *responses = responseObject;
    
    if (_cometClient) {
        id<DDQueue> incomingQueue = [_cometClient incomingQueue];
        
        for (NSDictionary *messageData in responses)
            {
            DDCometMessage *message = [DDCometMessage messageWithJson:messageData];
            [incomingQueue addObject:message];
            }
        [_cometClient messagesDidSend:messages];
    }
}


- (void)connectionDidFinishWithError:(NSURLSessionDataTask *)task error:(NSError *)error timeStamp:(NSDate *) timeStamp messages:(NSArray *) messages
{
    
    if (((NSHTTPURLResponse *)task.response).statusCode == 403)
        {
        NSDictionary * message =
        @{
          @"channel": @"/meta/handshake",
          @"successful": @"NO"
          };
        NSArray * responses = @[message];
        
        if (_cometClient)
            {
            id<DDQueue> incomingQueue = [_cometClient incomingQueue];
            
            for (NSDictionary *messageData in responses)
                {
                DDCometMessage *message = [DDCometMessage messageWithJson:messageData];
                [incomingQueue addObject:message];
                }
            [_cometClient messagesDidSend:messages];
            }
        }
    else
        {
        NSTimeInterval sinceConnect = fabs([timeStamp timeIntervalSinceNow]);
        
        //If the time since connect is greater than the timeout interval, it means we were in the background and should ignore the connection failure
        if (_cometClient && sinceConnect < task.originalRequest.timeoutInterval)
            {
            [_cometClient connectionFailedWithError:error withMessages:messages];
            }
        }
}





#pragma mark - WebSocket Methods

- (void)connectWebSocket
{
    [self disconnectWebSocket];
    
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:self.cometClient.endpointURL];
    self.webSocket = [[SRWebSocket alloc] initWithURLRequest:request];
    self.webSocket.delegate = self;
    [self.webSocket open];
}

- (void)writeMessageToWebSocket:(NSDictionary *)message
{
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
    if (error) {
        [self.cometClient connectionFailedWithError:error withMessages:@[message]];
    } else {
        NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [self.webSocket send:json];
    }
}

- (void)setupPingTimer
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, [self timeoutInterval] * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self pingWebSocket];
    });
}

- (void)pingWebSocket
{
    if (self.isConnected) {
        // send an empty array to do nothing, but keep the socket open
        NSLog(@"Sending ping...");
        [self.webSocket send:@"[]"];
        [self setupPingTimer];
    }
}

- (void)disconnectWebSocket
{
    _connected = NO;
    self.webSocket.delegate = nil;
    [self.webSocket close];
    self.webSocket = nil;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}


#pragma mark - SRWebSocketDelegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    [self.operationQueue addOperationWithBlock:^{
        if (webSocket.readyState == SR_OPEN)
            {
            _connected = YES;
            [self processMessages];
            }
        else
            {
            NSLog(@"WebSocket State is not ready state");
            }
    }];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    id data = message;
    if ([data isKindOfClass:[NSString class]])
        data = [data dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error = nil;
    NSArray *messages = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        [self.cometClient connectionFailedWithError:error withMessages:message];
    } else {
        if (_cometClient) {
            id<DDQueue> incomingQueue = [_cometClient incomingQueue];
        for (__strong NSDictionary *messageData in messages)
            {
                DDCometMessage *message = [DDCometMessage messageWithJson:messageData];
                [incomingQueue addObject:message];
            }
        }
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    [self.cometClient connectionFailedWithError:error withMessages:nil];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    [self disconnectWebSocket];
    
    {
        NSDictionary *errorInfo = @{NSLocalizedDescriptionKey: @"The WebSocket encountered an error."};
        if (reason) {
            NSMutableDictionary *mutableErrorInfo = [errorInfo mutableCopy];
            mutableErrorInfo[NSLocalizedFailureReasonErrorKey] = reason;
            errorInfo = mutableErrorInfo;
        }
        
        NSError *error = [NSError errorWithDomain:@"com.bmatcuk.BayeuxClient.WebSocketError" code:code userInfo:errorInfo];
        [self.cometClient connectionFailedWithError:error withMessages:nil];
    }
}

@end
