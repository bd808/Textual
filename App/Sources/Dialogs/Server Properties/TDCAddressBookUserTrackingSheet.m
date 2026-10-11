/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
 *       Please see Acknowledgements.pdf for additional information.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *  * Neither the name of Textual, "Codeux Software, LLC", nor the
 *    names of its contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *********************************************************************** */

#import "NSStringHelper.h"
#import "TLOLocalization.h"
#import "TVCValidatedTextField.h"
#import "TDCAddressBookSheetInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCAddressBookUserTrackingSheet ()
@property (nonatomic, strong) IBOutlet TVCValidatedTextField *userTrackingEntryNicknameTextField;
@property (nonatomic, strong) IBOutlet NSButton *trackUserActivityCheck;
@end

@implementation TDCAddressBookUserTrackingSheet

- (void)prepareInitialState
{
	self.userTrackingEntryNicknameTextField.stringValueIsInvalidOnEmpty = YES;
	self.userTrackingEntryNicknameTextField.stringValueUsesOnlyFirstToken = YES;

	self.userTrackingEntryNicknameTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if (currentValue.isHostmaskNickname == NO) {
			return TXTLS(@"CommonErrors[och-j5]");
		}

		return nil;
	};
}

- (void)loadConfig
{
	self.userTrackingEntryNicknameTextField.stringValue = self.config.hostmask;

	self.trackUserActivityCheck.state = self.config.trackUserActivity;
}

- (void)saveConfig
{
	self.config.hostmask = self.userTrackingEntryNicknameTextField.value;

	self.config.trackUserActivity = (self.trackUserActivityCheck.state == NSControlStateValueOn);
}

- (TVCValidatedTextField *)entryTextField
{
	return self.userTrackingEntryNicknameTextField;
}

@end

NS_ASSUME_NONNULL_END
