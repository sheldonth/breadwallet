//
//  BRReceiveViewController.m
//  BreadWallet
//
//  Created by Aaron Voisine on 5/8/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "BRReceiveViewController.h"
#import "BRRootViewController.h"
#import "BRPaymentRequest.h"
#import "BRWalletManager.h"
#import "BRWallet.h"
#import "BRBubbleView.h"
#import "BRMultiPeerManager.h"

#define QR_TIP      NSLocalizedString(@"Let others scan this QR code to get your bitcoin address. Anyone can send "\
                    "bitcoins to your wallet by transferring them to your address.", nil)
#define ADDRESS_TIP NSLocalizedString(@"This is your bitcoin address. Tap to copy it or send it by email or sms. The "\
                    "address will change each time you receive funds, but old addresses always work.", nil)

@interface BRReceiveViewController ()

@property (nonatomic, strong) BRBubbleView *tipView;
@property (nonatomic, assign) BOOL showTips, isMulti;
@property (nonatomic, strong) id protectedObserver;

@property (nonatomic, strong) IBOutlet UILabel *label;
@property (nonatomic, strong) IBOutlet UIButton *addressButton;
@property (nonatomic, strong) IBOutlet UIImageView *qrView;
@property (nonatomic, strong) IBOutlet UILabel *peerLabel;
#ifdef MULTIPEER
@property (nonatomic, strong) id transactionObserver;
#endif
@end

@implementation BRReceiveViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.protectedObserver =
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationProtectedDataDidBecomeAvailable object:nil
        queue:nil usingBlock:^(NSNotification *note) {
            [self updateAddress];
        }];
    
    self.peerLabel.alpha = 0;
#ifdef MULTIPEER
    self.transactionObserver =
        [[NSNotificationCenter defaultCenter]addObserverForName:BRWalletBalanceChangedNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            [self endMultiPeer];
        }];
#endif
    self.addressButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    [self updateAddress];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self.addressButton setTitle:nil forState:UIControlStateNormal];
    self.addressButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    [self updateAddress];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)dealloc
{
    if (self.protectedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.protectedObserver];
#ifdef MULTIPEER
    if (self.transactionObserver) [[NSNotificationCenter defaultCenter]removeObserver:self.transactionObserver];
#endif
}
- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
#ifdef MULTIPEER
    [self endMultiPeer];
#endif

}

- (void)updateAddress
{
    if (! [self.paymentRequest isValid]) return;

    NSString *s = [[NSString alloc] initWithData:self.paymentRequest.data encoding:NSUTF8StringEncoding];
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];

    [filter setValue:[s dataUsingEncoding:NSISOLatin1StringEncoding] forKey:@"inputMessage"];
    [filter setValue:@"L" forKey:@"inputCorrectionLevel"];
    UIGraphicsBeginImageContext(self.qrView.bounds.size);

    CGContextRef context = UIGraphicsGetCurrentContext();
    CGImageRef img = [[CIContext contextWithOptions:nil] createCGImage:filter.outputImage
                      fromRect:filter.outputImage.extent];

    if (context) {
        CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        CGContextDrawImage(context, CGContextGetClipBoundingBox(context), img);
        self.qrView.image = [UIImage imageWithCGImage:UIGraphicsGetImageFromCurrentImageContext().CGImage scale:1.0
                             orientation:UIImageOrientationDownMirrored];
        [self.addressButton setTitle:self.paymentAddress forState:UIControlStateNormal];
    }

    UIGraphicsEndImageContext();
    CGImageRelease(img);
}

- (BRPaymentRequest *)paymentRequest
{
    return [BRPaymentRequest requestWithString:self.paymentAddress];
}

- (NSString *)paymentAddress
{
    return [[[BRWalletManager sharedInstance] wallet] receiveAddress];
}

- (BOOL)nextTip
{
    if (self.tipView.alpha < 0.5) return [(id)self.parentViewController.parentViewController nextTip];

    BRBubbleView *v = self.tipView;

    self.tipView = nil;
    [v popOut];

    if ([v.text hasPrefix:QR_TIP]) {
        self.tipView = [BRBubbleView viewWithText:ADDRESS_TIP tipPoint:[self.addressButton.superview
                        convertPoint:CGPointMake(self.addressButton.center.x, self.addressButton.center.y - 10.0)
                        toView:self.view] tipDirection:BRBubbleTipDirectionDown];
        if (self.showTips) self.tipView.text = [self.tipView.text stringByAppendingString:@" (4/6)"];
        self.tipView.backgroundColor = v.backgroundColor;
        self.tipView.font = v.font;
        self.tipView.userInteractionEnabled = NO;
        [self.view addSubview:[self.tipView popIn]];
    }
    else if (self.showTips && [v.text hasPrefix:ADDRESS_TIP]) {
        self.showTips = NO;
        [(id)self.parentViewController.parentViewController tip:self];
    }

    return YES;
}

- (void)hideTips
{
    if (self.tipView.alpha > 0.5) [self.tipView popOut];
}

#ifdef MULTIPEER
- (void)beginMultiPeer
{
    if (self.isMulti) return;
    [[[BRMultiPeerManager sharedInstance]newPeerName]startAdvertisingWithCompletion:^{
        [self.peerLabel setText:[[[BRMultiPeerManager sharedInstance]peerID]displayName]];
        [UIView animateWithDuration:0.3 animations:^{
            [self.qrView setAlpha:0];
            [self.qrView.superview setAlpha:0];
            [self.peerLabel setAlpha:1];
        }];
        self.isMulti = YES;
    }];
}

- (void)endMultiPeer
{
    if (!self.isMulti) return;
    [[BRMultiPeerManager sharedInstance]stopAdvertisingWithCompletion:^{
        [UIView animateWithDuration:0.3 animations:^{
            [self.qrView setAlpha:1];
            [self.qrView.superview setAlpha:1];
            [self.peerLabel setAlpha:0];
        }];
        self.isMulti = NO;
    }];
}
#endif

#pragma mark - IBAction

- (IBAction)tip:(id)sender
{
    if ([self nextTip]) return;

    if (! [sender isKindOfClass:[UIGestureRecognizer class]] ||
        ([sender view] != self.qrView && ! [[sender view] isKindOfClass:[UILabel class]])) {
        if (! [sender isKindOfClass:[UIViewController class]]) return;
        self.showTips = YES;
    }

    self.tipView = [BRBubbleView viewWithText:QR_TIP
                    tipPoint:[self.qrView.superview convertPoint:self.qrView.center toView:self.view]
                    tipDirection:BRBubbleTipDirectionUp];
    if (self.showTips) self.tipView.text = [self.tipView.text stringByAppendingString:@" (3/6)"];
    self.tipView.backgroundColor = [UIColor orangeColor];
    self.tipView.font = [UIFont fontWithName:@"HelveticaNeue" size:15.0];
    [self.view addSubview:[self.tipView popIn]];
}

- (IBAction)address:(id)sender
{
    if ([self nextTip]) return;

    UIActionSheet *a = [UIActionSheet new];

    a.title = [NSString stringWithFormat:NSLocalizedString(@"Receive bitcoins at this address: %@", nil),
               self.paymentAddress];
    a.delegate = self;
    [a addButtonWithTitle:NSLocalizedString(@"copy to clipboard", nil)];
    if ([MFMailComposeViewController canSendMail]) [a addButtonWithTitle:NSLocalizedString(@"send as email", nil)];
#if ! TARGET_IPHONE_SIMULATOR
    if ([MFMessageComposeViewController canSendText]) [a addButtonWithTitle:NSLocalizedString(@"send as message", nil)];
#endif
#ifdef MULTIPEER
    if (self.isMulti)
        [a addButtonWithTitle:NSLocalizedString(@"cancel nearby", nil)];
    else
        [a addButtonWithTitle:NSLocalizedString(@"send to nearby devices", nil)];
#endif
    [a addButtonWithTitle:NSLocalizedString(@"cancel", nil)];
    a.cancelButtonIndex = a.numberOfButtons - 1;
    [a showInView:[[UIApplication sharedApplication] keyWindow]];
}

- (void)peerLabelTap:(id)sender
{
#ifdef MULTIPEER
    [self endMultiPeer];
#endif
}


#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];

    //TODO: allow user to specify a request amount
    //TODO: allow user to create a payment protocol request object, and use merge avoidance techniques:
    //      https://medium.com/@octskyward/merge-avoidance-7f95a386692f
    if ([title isEqual:NSLocalizedString(@"copy to clipboard", nil)]) {
        [[UIPasteboard generalPasteboard] setString:self.paymentAddress];

        [self.view
         addSubview:[[[BRBubbleView viewWithText:NSLocalizedString(@"copied", nil)
                       center:CGPointMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height/2.0 - 130.0)]
                      popIn] popOutAfterDelay:2.0]];
    }
    else if ([title isEqual:NSLocalizedString(@"send as email", nil)]) {
        //TODO: implement BIP71 payment protocol mime attachement
        // https://github.com/bitcoin/bips/blob/master/bip-0071.mediawiki
        
        if ([MFMailComposeViewController canSendMail]) {
            MFMailComposeViewController *c = [MFMailComposeViewController new];
            
            [c setSubject:NSLocalizedString(@"Bitcoin address", nil)];
            [c setMessageBody:[@"bitcoin:" stringByAppendingString:self.paymentAddress] isHTML:NO];
            c.mailComposeDelegate = self;
            [self.navigationController presentViewController:c animated:YES completion:nil];
            c.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"wallpaper-default"]];
        }
        else {
            [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"email not configured", nil) delegate:nil
              cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
        }
    }
    else if ([title isEqual:NSLocalizedString(@"send as message", nil)]) {
        if ([MFMessageComposeViewController canSendText]) {
            MFMessageComposeViewController *c = [MFMessageComposeViewController new];
            
            c.body = [@"bitcoin:" stringByAppendingString:self.paymentAddress];
            c.messageComposeDelegate = self;
            [self.navigationController presentViewController:c animated:YES completion:nil];
            c.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"wallpaper-default"]];
        }
        else {
            [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"sms not currently available", nil)
              delegate:nil cancelButtonTitle:NSLocalizedString(@"ok", nil) otherButtonTitles:nil] show];
        }
    }
#ifdef MULTIPEER
    else if ([title isEqual:NSLocalizedString(@"cancel nearby", nil)])
    {
        [self endMultiPeer];
    }
    else if ([title isEqual:NSLocalizedString(@"send to nearby devices", nil)])
    {
        [self beginMultiPeer];
    }
#endif
}

#pragma mark - MFMessageComposeViewControllerDelegate

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
didFinishWithResult:(MessageComposeResult)result
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result
error:(NSError *)error
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

@end
