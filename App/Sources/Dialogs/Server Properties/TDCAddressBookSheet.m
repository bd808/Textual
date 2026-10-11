/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

#import "TVCValidatedTextField.h"
#import "TDCAddressBookSheetInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation TDCAddressBookSheet

+ (TDCAddressBookSheet *)sheetForNewEntryOfType:(IRCAddressBookEntryType)entryType
{
	NSParameterAssert(entryType == IRCAddressBookEntryTypeIgnore ||
					  entryType == IRCAddressBookEntryTypeUserTracking);

	if (entryType == IRCAddressBookEntryTypeIgnore) {
		return [self sheetWithConfig:[IRCAddressBookEntryMutable newIgnoreEntry]];
	}

	return [self sheetWithConfig:[IRCAddressBookEntryMutable newUserTrackingEntry]];
}

+ (TDCAddressBookSheet *)sheetWithConfig:(IRCAddressBookEntry *)config
{
	NSParameterAssert(config != nil);
	NSParameterAssert(config.entryType == IRCAddressBookEntryTypeIgnore ||
					  config.entryType == IRCAddressBookEntryTypeUserTracking);

	if (config.entryType == IRCAddressBookEntryTypeIgnore) {
		return [[TDCAddressBookIgnoreSheet alloc] initWithConfig:config];
	}

	return [[TDCAddressBookUserTrackingSheet alloc] initWithConfig:config];
}

- (instancetype)initWithConfig:(IRCAddressBookEntry *)config
{
	NSParameterAssert(config != nil);

	if ((self = [super initWithWindow:nil])) {
		self.config = [config mutableCopy];

		[self loadNib];

		[self prepareInitialState];

		[self loadConfig];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[self doesNotRecognizeSelector:_cmd];
}

- (void)loadConfig
{
	[self doesNotRecognizeSelector:_cmd];
}

- (void)saveConfig
{
	[self doesNotRecognizeSelector:_cmd];
}

- (TVCValidatedTextField *)entryTextField
{
	[self doesNotRecognizeSelector:_cmd];

	__builtin_unreachable(); // -doesNotRecognizeSelector: raises
}

- (void)start
{
	[self.sheet makeFirstResponder:self.entryTextField];

	[self startSheet];
}

- (void)ok:(nullable id)sender
{
	if ([self okOrErrorForTextField:self.entryTextField] == NO) {
		return;
	}

	[self saveConfig];

	id delegate = self.delegate;

	if ([delegate respondsToSelector:@selector(addressBookSheet:onOk:)]) {
		[delegate addressBookSheet:self onOk:[self.config copy]];
	}

	[super ok:nil];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	id delegate = self.delegate;

	if ([delegate respondsToSelector:@selector(addressBookSheetWillClose:)]) {
		[delegate addressBookSheetWillClose:self];
	}

	[super windowWillClose:note];
}

@end

NS_ASSUME_NONNULL_END
