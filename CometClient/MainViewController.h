
#import "DDCometClient.h"

@interface MainViewController : UIViewController <UITextFieldDelegate, DDCometClientDelegate>
{
@private
	DDCometClient *cometClient;
}

@property (nonatomic, weak) IBOutlet UITextView *textView;
@property (nonatomic, weak) IBOutlet UITextField *textField;

@end
