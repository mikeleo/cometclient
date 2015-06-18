
#import "DDCometAFLongPollingTransport.h"
#import "DDCometClient.h"
#import "DDCometMessage.h"
#import "DDQueue.h"
#import <AFNetworking.h>

#define kDefaultConnectionTimeout 60.0
#define kConnectionTimeoutVariance 5
#define kMinPollTime 0.020  // The minimum time between polls in seconds

@interface DDCometAF2LongPollingTransport ()
    
@property (nonatomic, weak) DDCometClient * cometClient;
@property (nonatomic, strong) AFHTTPSessionManager * sessionManager;

@property (nonatomic, assign) BOOL shouldCancel;

@property (nonatomic, assign) BOOL polling;
@property (nonatomic, strong) NSDate * lastPoll;
@property (nonatomic, strong) dispatch_queue_t queue;

- (NSArray *)outgoingMessages;

@end

@implementation DDComet2AFLongPollingTransport
//static void * const responseDataKey = (void*)&responseDataKey;
//static void * const messagesKey = (void*)&messagesKey;
//static void * const timestampKey = (void*)&timestampKey;
//static void * const statusKey = (void*)&statusKey;

- (id)initWithClient:(DDCometClient *)client
{
	if ((self = [super init]))
        {
        _cometClient = client;
//		_responseDatas = [[NSMutableDictionary alloc] initWithCapacity:2];
        self.queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.timeoutIntervalForRequest = self.timeoutInterval;
        AFHTTPSessionManager * sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:_cometClient.endpointURL sessionConfiguration:configuration];
        sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
        sessionManager.completionQueue = _queue;
        self.sessionManager = sessionManager;
        }
	return self;
}


- (void)start
{
	[self performSelectorInBackground:@selector(main) withObject:nil];
}

- (void)cancel
{
	_shouldCancel = YES;
    _cometClient = nil;
}

#pragma mark -

- (void)main
{
	do
	{
		@autoreleasepool {
			NSArray *messages = [self outgoingMessages];
			
			BOOL isPolling;
			if ([messages count] == 0)
			{
				if (_cometClient.state == DDCometStateConnected && !_polling && (!_lastPoll || fabs([_lastPoll timeIntervalSinceNow]) > kMinPollTime))
				{
					isPolling = YES;
                    _polling = YES;
					DDCometMessage *message = [DDCometMessage messageWithChannel:@"/meta/connect"];
					message.clientID = _cometClient.clientID;
					message.connectionType = @"long-polling";
					NSLog(@"Sending long-poll message: %@", message);
					messages = @[message];
                    _lastPoll = [NSDate date];
				}
				else
				{
					[NSThread sleepForTimeInterval:kMinPollTime / 2];
                    continue;
				}
			}
			
            void (^successBlock)(NSURLSessionDataTask *task, id responseObject, NSDate *timeStamp, NSArray *messages) =
                  ^(NSURLSessionDataTask *task, id responseObject, NSDate *timeStamp, NSArray *messages)
            {
            [self connectionDidFinishWithSuccess:task responseObject:responseObject timeStamp:timeStamp messages:messages];
            };
            
            void (^failureBlock)(NSURLSessionDataTask *task, NSError *error, NSDate *timeStamp, NSArray *messages) =
                ^(NSURLSessionDataTask *task, NSError *error, NSDate *timeStamp, NSArray *messages) {
                    [self connectionDidFinishWithError:task error:error timeStamp:timeStamp messages:messages];
            };
            
			NSURLSessionDataTask *sessionDataTask = [self sendMessages:messages
                                                               success: successBlock failure:failureBlock];
			if (sessionDataTask)
                {
				NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
				while ([runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]])
                    {
					if (isPolling)
                        {
						if (_shouldCancel)
                            {
							_shouldCancel = NO;
							[sessionDataTask cancel];
                            }
						else
                            {
                            messages = [self outgoingMessages];
                            [self sendMessages:messages success:successBlock failure:failureBlock];
                            }
                        }
                    }
                }
		}
	} while (_cometClient.state != DDCometStateDisconnected && !_shouldCancel);
}

- (NSURLSessionDataTask *)sendMessages:(NSArray *)messages
                          success:(void (^)(NSURLSessionDataTask *task, id responseObject, NSDate * timeStamp, NSArray * messages))success
                          failure:(void (^)(NSURLSessionDataTask *task, NSError *error, NSDate * timeStamp, NSArray * messages))failure
{
	if ([messages count] != 0)
        {
        __block NSDate * timestampKey = [NSDate date];
        __block NSArray * messagesCopy = [NSArray arrayWithArray:messages];
        
        NSURLSessionDataTask *sessionDataTask =
            [self requestWithMessages:messages
                              success:^(NSURLSessionDataTask *task, id responseObject) {
                                  if (success)
                                      {
                                      success(task, responseObject, timestampKey, messagesCopy);
                                      }
                              }
                              failure:^(NSURLSessionDataTask *task, NSError *error) {
                                  if (failure)
                                      {
                                      failure(task, error, timestampKey, messagesCopy);
                                      }
                              }];
        return sessionDataTask;
        }
    return nil;
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

- (NSURLSessionDataTask *)requestWithMessages:(NSArray *)messages
                                        success:(void (^)(NSURLSessionDataTask *task, id responseObject))success
                                        failure:(void (^)(NSURLSessionDataTask *task, NSError *error))failure
{
    NSMutableArray *msgArr = [NSMutableArray arrayWithCapacity:messages.count];
    for (int i = 0; i < messages.count;i++) {
        msgArr[i] = ((DDCometMessage*)messages[i]).proxyForJson;
    }
    
    NSURLSessionDataTask * sessionDataTask =
    [_sessionManager POST:@"" parameters:msgArr success:success failure:failure];
    
    return sessionDataTask;
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
            if (_polling && [message.channel isEqualToString:@"/meta/connect"]) {
                _polling = NO;
            }
            [incomingQueue addObject:message];
        }
        [_cometClient messagesDidSend:messages];
    }
}

- (void)connectionDidFinishWithError:(NSURLSessionDataTask *)task error:(NSError *)error timeStamp:(NSDate *) timeStamp messages:(NSArray *) messages
{
    
    _polling = NO;
    
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
                if (_polling && [message.channel isEqualToString:@"/meta/connect"]) {
                    _polling = NO;
                }
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

@end

