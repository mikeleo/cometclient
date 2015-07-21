
#import "DDCometMessage.h"
#import <objc/runtime.h>

@interface NSDate (ISO8601)

+ (NSDate *)dateWithISO8601String:(NSString *)string;
- (NSString *)ISO8601Representation;

@end

@implementation NSDate (ISO8601)
static __strong NSDateFormatter* FMT;

+(void)initFormat
{
    if (!FMT) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        [fmt setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
        FMT = fmt;
    }
}

+ (NSDate *)dateWithISO8601String:(NSString *)string
{
	[NSDate initFormat];
    return [FMT dateFromString:string];
}

- (NSString *)ISO8601Representation
{
    [NSDate initFormat];
    return [FMT stringFromDate:self];
}

@end

@interface NSError (Bayeux)

+ (NSError *)errorWithBayeuxFormat:(NSString *)string;
- (NSString *)bayeuxFormat;

@end

@implementation NSError (Bayeux)

+ (NSError *)errorWithBayeuxFormat:(NSString *)string
{
	NSArray *components = [string componentsSeparatedByString:@":"];
	NSInteger code = [components[0] integerValue];
	NSDictionary *userInfo = @{NSLocalizedDescriptionKey: components[2]};
	return [[NSError alloc] initWithDomain:@"" code:code userInfo:userInfo];
}

- (NSString *)bayeuxFormat
{
	NSString *args = @"";
	NSArray *components = @[[NSString stringWithFormat:@"%ld", (long)[self code]], args, [self localizedDescription]];
	return [components componentsJoinedByString:@":"];
}

@end

@implementation DDCometMessage

@synthesize channel = m_channel,
	version = m_version,
	minimumVersion = m_minimumVersion,
	supportedConnectionTypes = m_supportedConnectionTypes,
	clientID = m_clientID,
	advice = m_advice,
	connectionType = m_connectionType,
	ID = m_ID,
	timestamp = m_timestamp,
	data = m_data,
	successful = m_successful,
	subscription = m_subscription,
	error = m_error,
	ext = m_ext;


+ (DDCometMessage *)messageWithChannel:(NSString *)channel
{
	DDCometMessage *message = [[DDCometMessage alloc] init];
	message.channel = channel;
	return message;
}

@end

@implementation DDCometMessage (JSON)

+ (DDCometMessage *)messageWithJson:(NSDictionary *)jsonData
{
	DDCometMessage *message = [[DDCometMessage alloc] init];
	for (NSString *key in [jsonData keyEnumerator])
	{
		id object = jsonData[key];
		
		if ([key isEqualToString:@"channel"])
			message.channel = object;
		else if ([key isEqualToString:@"version"])
			message.version = object;
		else if ([key isEqualToString:@"minimumVersion"])
			message.minimumVersion = object;
		else if ([key isEqualToString:@"supportedConnectionTypes"])
			message.supportedConnectionTypes = object;
		else if ([key isEqualToString:@"clientId"])
			message.clientID = object;
		else if ([key isEqualToString:@"advice"])
			message.advice = object;
		else if ([key isEqualToString:@"connectionType"])
			message.connectionType = object;
		else if ([key isEqualToString:@"id"])
			message.ID = object;
		else if ([key isEqualToString:@"timestamp"])
			message.timestamp = [NSDate dateWithISO8601String:object];
		else if ([key isEqualToString:@"data"])
			message.data = object;
		else if ([key isEqualToString:@"successful"])
			message.successful = object;
		else if ([key isEqualToString:@"subscription"])
			message.subscription = object;
		else if ([key isEqualToString:@"error"])
			message.error = [NSError errorWithBayeuxFormat:object];
		else if ([key isEqualToString:@"ext"])
			message.ext = object;
	}
	return message;
}

- (NSDictionary *)proxyForJson
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	if (m_channel)
		dict[@"channel"] = m_channel;
	if (m_version)
		dict[@"version"] = m_version;
	if (m_minimumVersion)
		dict[@"minimumVersion"] = m_minimumVersion;
	if (m_supportedConnectionTypes)
		dict[@"supportedConnectionTypes"] = m_supportedConnectionTypes;
	if (m_clientID)
		dict[@"clientId"] = m_clientID;
	if (m_advice)
		dict[@"advice"] = m_advice;
	if (m_connectionType)
		dict[@"connectionType"] = m_connectionType;
	if (m_ID)
		dict[@"id"] = m_ID;
	if (m_timestamp)
		dict[@"timestamp"] = [m_timestamp ISO8601Representation];
	if (m_data) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        if ([m_data respondsToSelector:@selector(asDictionary)]) {
            dict[@"data"] = [m_data performSelector:@selector(asDictionary)];
#pragma clang diagnostic pop
        } else {
            dict[@"data"] = m_data;
        }
    }
	if (m_successful)
		dict[@"successful"] = m_successful;
	if (m_subscription)
		dict[@"subscription"] = m_subscription;
	if (m_error)
		dict[@"error"] = [m_error bayeuxFormat];
	if (m_ext)
		dict[@"ext"] = m_ext;
	return dict;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ %@", [super description], [self proxyForJson]];
}

@end
