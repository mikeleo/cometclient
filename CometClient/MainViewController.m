
#import "MainViewController.h"
#import "DDCometClient.h"
#import "DDCometMessage.h"


@implementation MainViewController


- (void)viewDidLoad
{
	if (cometClient== nil)
	{
		cometClient = [[DDCometClient alloc] initWithURL:[NSURL URLWithString:@"http://localhost:7881/cometd"]];
		cometClient.delegate = self;
		[cometClient scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [cometClient handshakeWithData:    @{
                                         @"staffId": @"",
                                         @"token": @"bWxlb0B2b2NlcmEuY29tOjE0MjkxNDE2MTI2OTE6NGQ1MTA0ZWUtNzg1Ni00ODg0LWE1M2QtYTcwNDgxYWRlZDEyOmE3MGYwZTU3M2M0YjA1ZmU2NDNiNjU5MWQ4YjYxZGVj"
                                         //@"token": @"bWlrZToxNDI5MTIwMTI1OTY2OmIyNjgxM2JmLTVlOTItNDlmNy1iYzNjLWFiNTFlMTU4M2JlZjo1NzUwMzk2MDY2ZjQ2NWU3NzNlZmRhMTA1ODAyNTEwNA"
                                         }];
	}
}

- (void)viewWillAppear:(BOOL)animated
{
	[_textField becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

#pragma mark -

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:_textField.text, @"chat", @"iPhone user", @"user", nil];
	[cometClient publishData:data toChannel:@"/chat/demo"];
	
	_textField.text = @"";
	return YES;
}

- (void)appendText:(NSString *)text
{
	_textView.text = [_textView.text stringByAppendingFormat:@"%@\n", text];
}

#pragma mark -

- (void)cometClientHandshakeDidSucceed:(DDCometClient *)client
{
	NSLog(@"Handshake succeeded");

	[self appendText:@"[connected]"];
	
	[client subscribeToChannel:@"/chat/demo" target:self selector:@selector(chatMessageReceived:)];
	[client subscribeToChannel:@"/members/demo" target:self selector:@selector(membershipMessageReceived:)];
	
	NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:@"/chat/demo", @"room", @"iPhone user", @"user", nil];
	[cometClient publishData:data toChannel:@"/service/members"];
}

- (void)cometClient:(DDCometClient *)client handshakeDidFailWithError:(NSError *)error
{
	NSLog(@"Handshake failed");
}

- (void)cometClientConnectDidSucceed:(DDCometClient *)client
{
	NSLog(@"Connect succeeded");
}

- (void)cometClient:(DDCometClient *)client connectDidFailWithError:(NSError *)error
{
	NSLog(@"Connect failed");
}

- (void)cometClient:(DDCometClient *)client subscriptionDidSucceed:(DDCometSubscription *)subscription
{
	NSLog(@"Subsription succeeded");
}

- (void)cometClient:(DDCometClient *)client subscription:(DDCometSubscription *)subscription didFailWithError:(NSError *)error
{
	NSLog(@"Subsription failed");
}

- (void)chatMessageReceived:(DDCometMessage *)message
{
	if (message.successful == nil)
		[self appendText:[NSString stringWithFormat:@"%@: %@", [message.data objectForKey:@"user"], [message.data objectForKey:@"chat"]]];
	else if (![message.successful boolValue])
		[self appendText:@"Unable to send message"];
}

- (void)membershipMessageReceived:(DDCometMessage *)message
{
	if ([message.data isKindOfClass:[NSDictionary class]])
		[self appendText:[NSString stringWithFormat:@"[%@ are in the chat]", [message.data objectForKey:@"user"]]];
	if ([message.data isKindOfClass:[NSArray class]])
		[self appendText:[NSString stringWithFormat:@"[%@ are in the chat]", [message.data componentsJoinedByString:@", "]]];
}

@end
