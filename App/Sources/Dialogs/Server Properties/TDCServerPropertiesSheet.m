/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2019 Codeux Software, LLC & respective contributors.
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
#import "IRCClientConfigPrivate.h"
#import "IRCClientPrivate.h"
#import "IRCAddressBook.h"
#import "IRCChannel.h"
#import "TLOLocalization.h"
#import "TPCPreferencesUserDefaults.h"
#import "TVCContentNavigationOutlineViewPrivate.h"
#import "TVCValidatedTextField.h"
#import "TDCAlert.h"
#import "TDCPreferencesControllerPrivate.h"
#import "TDCServerPropertiesSheetPrivate.h"
#import "TDCServerPropertiesPanePrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TDCServerPropertiesSheet ()
@property (nonatomic, strong, readwrite, nullable) IRCClient *client;
@property (nonatomic, copy, readwrite, nullable) NSString *clientId;
@property (nonatomic, strong) IRCClientConfigMutable *config;
@property (nonatomic, copy) NSArray *navigationTreeMatrix;
@property (nonatomic, copy) NSDictionary *encodingList;
@property (nonatomic, strong) IBOutlet NSView *contentViewConnectCommands;
@property (nonatomic, strong) IBOutlet NSView *contentViewDisconnectMessages;
@property (nonatomic, strong) IBOutlet NSView *contentViewEncoding;
@property (nonatomic, strong) IBOutlet NSView *contentViewFloodControl;
@property (nonatomic, strong) IBOutlet NSView *contentViewNetworkSocket;
@property (nonatomic, strong) IBOutlet NSView *contentViewProxyServer;
@property (nonatomic, strong) IBOutlet NSView *contentViewProxyServerInputView;
@property (nonatomic, strong) IBOutlet NSView *contentViewProxyServerSystemSocksView;
@property (nonatomic, strong) IBOutlet NSView *contentViewProxyServerTorBrowserView;
@property (nonatomic, strong) IBOutlet NSView *contentViewRedundancy;
@property (nonatomic, strong) IBOutlet NSView *contentViewZncBouncer;
@property (nonatomic, weak) IBOutlet NSButton *connectionIPv4AddressTypeCheck;
@property (nonatomic, weak) IBOutlet NSButton *connectionIPv6AddressTypeCheck;
@property (nonatomic, weak) IBOutlet NSButton *connectionDefaultAddressTypeCheck;
@property (nonatomic, weak) IBOutlet NSButton *disconnectOnReachabilityChangeCheck;
@property (nonatomic, weak) IBOutlet NSButton *performDisconnectOnPongTimerCheck;
@property (nonatomic, weak) IBOutlet NSButton *pongTimerCheck;
@property (nonatomic, weak) IBOutlet NSButton *setInvisibleModeOnConnectCheck;
@property (nonatomic, weak) IBOutlet NSButton *validateServerCertificateChainCheck;
@property (nonatomic, weak) IBOutlet NSButton *viewListOfPreferredCipherSuitesButton;
@property (nonatomic, weak) IBOutlet NSButton *zncIgnoreConfiguredAutojoinCheck;
@property (nonatomic, weak) IBOutlet NSButton *zncIgnorePlaybackNotificationsCheck;
@property (nonatomic, weak) IBOutlet NSButton *zncOnlyPlaybackLatestCheck;
@property (nonatomic, weak) IBOutlet NSPopUpButton *fallbackEncodingButton;
@property (nonatomic, weak) IBOutlet NSPopUpButton *primaryEncodingButton;
@property (nonatomic, weak) IBOutlet NSPopUpButton *preferredCipherSuitesButton;
@property (nonatomic, weak) IBOutlet NSPopUpButton *proxyTypeButton;
@property (nonatomic, weak) IBOutlet NSSlider *floodControlDelayTimerSlider;
@property (nonatomic, weak) IBOutlet NSSlider *floodControlMessageCountSlider;
@property (nonatomic, weak) IBOutlet NSTextField *proxyPasswordTextField;
@property (nonatomic, weak) IBOutlet NSTextField *proxyUsernameTextField;
@property (nonatomic, weak) IBOutlet TVCContentNavigationOutlineView *navigationOutlineView;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *normalLeavingCommentTextField;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *proxyAddressTextField;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *proxyPortTextField;
@property (nonatomic, weak) IBOutlet TVCValidatedTextField *sleepModeQuitMessageTextField;
@property (nonatomic, unsafe_unretained) IBOutlet NSTextView *connectCommandsField;
@property (nonatomic, assign) NSUInteger floodControlDelayTimerSliderTempValue;
@property (nonatomic, assign) NSUInteger floodControlMessageCountSliderTempValue;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesChannelsPane *channelsPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesHighlightsPane *highlightsPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesAddressBookPane *addressBookPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesGeneralPane *generalPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesIdentityPane *identityPane;
@property (nonatomic, strong) IBOutlet TDCServerPropertiesClientCertificatePane *clientCertificatePane;
@property (nonatomic, copy) NSArray<TDCServerPropertiesPane *> *panes;

- (IBAction)proxyTypeChanged:(nullable id)sender;
- (IBAction)toggleAdvancedEncodings:(nullable id)sender;

- (IBAction)openProxySettingsInSystemPreferences:(nullable id)sender;

- (IBAction)preferredCipherSuitesChanged:(nullable id)sender;
- (IBAction)preferredCipherSuitesViewList:(nullable id)sender;

- (IBAction)preferredInternetProtocolChanged:(nullable id)sender;
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation TDCServerPropertiesSheet

- (instancetype)initWithClient:(nullable IRCClient *)client
{
	if ((self = [super initWithWindow:nil])) {
		if (client) {
			self.client = client;
			self.clientId = client.uniqueIdentifier;

			[client updateStoredConfiguration];

			self.config = [client.config mutableCopy];
		} else {
			self.config = [IRCClientConfigMutable new];
		}

		[self prepareInitialState];

		[self loadConfig];

		return self;
	}

	return nil;
}

- (void)prepareInitialState
{
	[self loadNib];

	/* Connect commands text box better font */
	self.connectCommandsField.font = [NSFont systemFontOfSize:13.0];

	self.connectCommandsField.textContainerInset = NSMakeSize(1, 3);

	/* Normal leaving comment */
	self.normalLeavingCommentTextField.textDidChangeCallback = self;

	self.normalLeavingCommentTextField.stringValueIsInvalidOnEmpty = NO;
	self.normalLeavingCommentTextField.stringValueIsTrimmed = YES;
	self.normalLeavingCommentTextField.stringValueUsesOnlyFirstToken = NO;

	self.normalLeavingCommentTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if ([currentValue containsCharactersFromCharacterSet:[NSCharacterSet newlineCharacterSet]]) {
			return TXTLS(@"CommonErrors[gas-v8]");
		}

		if (currentValue.length > 390) {
			return TXTLS(@"CommonErrors[2cb-af]", 390);
		}

		return nil;
	};

	/* Sleep mode leaving comment */
	self.sleepModeQuitMessageTextField.textDidChangeCallback = self;

	self.sleepModeQuitMessageTextField.stringValueIsInvalidOnEmpty = NO;
	self.sleepModeQuitMessageTextField.stringValueIsTrimmed = YES;
	self.sleepModeQuitMessageTextField.stringValueUsesOnlyFirstToken = NO;

	self.sleepModeQuitMessageTextField.validationBlock = ^NSString *(NSString *currentValue) {
		if ([currentValue containsCharactersFromCharacterSet:[NSCharacterSet newlineCharacterSet]]) {
			return TXTLS(@"CommonErrors[gas-v8]");
		}

		if (currentValue.length > 390) {
			return TXTLS(@"CommonErrors[2cb-af]", 390);
		}

		return nil;
	};

	/* Proxy address */
	self.proxyAddressTextField.textDidChangeCallback = self;

	self.proxyAddressTextField.stringValueIsInvalidOnEmpty = NO;
	self.proxyAddressTextField.stringValueIsTrimmed = YES;
	self.proxyAddressTextField.stringValueUsesOnlyFirstToken = YES;

	self.proxyAddressTextField.performValidationWhenEmpty = YES;

	/* Weak: the sheet owns the fields that keep these blocks, so the sheet
	 (and its client) leaked */
	__weak typeof(self) weakSelf = self;

	self.proxyAddressTextField.validationBlock = ^NSString *(NSString *currentValue) {
		NSInteger proxyType = weakSelf.proxyTypeButton.selectedTag;

		if (proxyType == IRCConnectionProxyTypeSocks5 ||
			proxyType == IRCConnectionProxyTypeHTTP ||
			proxyType == IRCConnectionProxyTypeHTTPS)
		{
			if (currentValue.isValidInternetAddress == NO) {
				return TXTLS(@"TDCServerPropertiesSheet[tlo-b6]");
			}
		}

		return nil;
	};

	/* Proxy port */
	self.proxyPortTextField.textDidChangeCallback = self;

	self.proxyPortTextField.stringValueIsInvalidOnEmpty = NO;
	self.proxyPortTextField.stringValueIsTrimmed = YES;
	self.proxyPortTextField.stringValueUsesOnlyFirstToken = NO;

	self.proxyPortTextField.performValidationWhenEmpty = YES;

	self.proxyPortTextField.defaultValue = [NSString stringWithUnsignedInteger:IRCConnectionDefaultProxyPort];

	self.proxyPortTextField.validationBlock = ^NSString *(NSString *currentValue) {
		NSInteger proxyType = weakSelf.proxyTypeButton.selectedTag;

		if (proxyType == IRCConnectionProxyTypeSocks5 ||
			proxyType == IRCConnectionProxyTypeHTTP ||
			proxyType == IRCConnectionProxyTypeHTTPS)
		{
			if (currentValue.isValidInternetPort == NO) {
				return TXTLS(@"CommonErrors[l0c-nb]");
			}
		}

		return nil;
	};

	/* Setup others */
	[self addConfigurationDidChangeObserver];

	self.panes = @[self.generalPane, self.identityPane, self.clientCertificatePane,
				   self.channelsPane, self.highlightsPane, self.addressBookPane];

	for (TDCServerPropertiesPane *pane in self.panes) {
		[pane prepareInitialState];
	}

	[self populateEncodings];

	[self populateTabViewList];
}

- (void)populateTabViewList
{
#define _groupItem(_label_, _children_) 	\
	[[TVCContentNavigationOutlineViewItem alloc] initWithLabel:TXTLS(_label_) identifier:0 view:nil firstResponder:nil children:(_children_)]

#define _childItem(_label_, _identifier_) 	\
	[[TVCContentNavigationOutlineViewItem alloc] initWithLabel:TXTLS(_label_) identifier:TDCServerPropertiesSheetSelection ##_identifier_ view:self.contentView ##_identifier_ firstResponder:nil]

#define _paneItem(_label_, _identifier_, _pane_) 	\
	[self navigationItemWithLabel:TXTLS(_label_) selection:TDCServerPropertiesSheetSelection ##_identifier_ pane:(_pane_)]

	NSArray *generalSectionChildren = @[
		_paneItem(@"TDCServerPropertiesSheet[8zc-6y]", AddressBook, self.addressBookPane),
		_paneItem(@"TDCServerPropertiesSheet[5oz-07]", Autojoin, self.channelsPane),
		_childItem(@"TDCServerPropertiesSheet[hip-13]", ConnectCommands),
		_childItem(@"TDCServerPropertiesSheet[8ug-ka]", Encoding),
		_paneItem(@"TDCServerPropertiesSheet[ehx-4d]", General, self.generalPane),
		_paneItem(@"TDCServerPropertiesSheet[8ik-qo]", Identity, self.identityPane),
		_paneItem(@"TDCServerPropertiesSheet[jtx-hn]", Highlights, self.highlightsPane),
		_childItem(@"TDCServerPropertiesSheet[j34-yr]", DisconnectMessages),
	];

	NSArray *vendorSectionChildren = @[
		_childItem(@"TDCServerPropertiesSheet[fsj-7f]", ZncBouncer)
	];

	NSArray *advancedSectionChildren = @[
		_paneItem(@"TDCServerPropertiesSheet[ce7-kc]", ClientCertificate, self.clientCertificatePane),
		_childItem(@"TDCServerPropertiesSheet[fcr-w8]", FloodControl),
		_childItem(@"TDCServerPropertiesSheet[ffy-xt]", NetworkSocket),
		_childItem(@"TDCServerPropertiesSheet[t52-7a]", ProxyServer),
		_childItem(@"TDCServerPropertiesSheet[36n-u9]", Redundancy)
	];

	NSArray *navigationTreeMatrix = @[
		_groupItem(@"TDCServerPropertiesSheet[lww-pc]", generalSectionChildren),
		_groupItem(@"TDCServerPropertiesSheet[v27-8w]", vendorSectionChildren),
		_groupItem(@"TDCServerPropertiesSheet[8uw-tz]", advancedSectionChildren)
	];

#undef _groupItem
#undef _childItem
#undef _paneItem

	self.navigationOutlineView.navigationTreeMatrix = navigationTreeMatrix;

	/* Auto layout will grow view beyond these values.
	 We are just declaring the default which doesn't matter much. */
	self.navigationOutlineView.contentViewPreferredWidth = 100;
	self.navigationOutlineView.contentViewPreferredHeight = 100;

	self.navigationOutlineView.expandParentOnDoubleClick = YES;

	[self.navigationOutlineView expandItem:navigationTreeMatrix[0]];
}

- (TVCContentNavigationOutlineViewItem *)navigationItemWithLabel:(NSString *)label selection:(TDCServerPropertiesSheetSelection)selection pane:(TDCServerPropertiesPane *)pane
{
	pane.selection = selection;

	return [[TVCContentNavigationOutlineViewItem alloc] initWithLabel:label identifier:selection view:pane.view firstResponder:nil];
}

- (void)populateEncodings
{
	[self.primaryEncodingButton removeAllItems];

	[self.fallbackEncodingButton removeAllItems];

	/* Build list of encodings */
	self.encodingList = [NSString supportedStringEncodingsWithTitle:NO];

	NSArray *encodingNames = self.encodingList.sortedDictionaryKeys;

	/* What we are basically doing now is sorting all the encodings, then removing
	 UTF-8 from the sorted list and inserting it at the top of the list. */
	NSString *utf8title = [NSString localizedNameOfStringEncoding:NSUTF8StringEncoding];

	NSMutableArray *encodingsToAdd = [encodingNames mutableCopy];

	[encodingsToAdd removeObject:utf8title];

	[self.primaryEncodingButton addItemWithTitle:utf8title];

	[self.fallbackEncodingButton addItemWithTitle:utf8title];

	/* Add the encodings to the popup list. This for loop will find the first
	 parentheses opening and compare everything before it to the one found for
	 the previous encoding. If the prefix has changed, then a separator is
	 inserted. This groups the encodings.*/
	/* We do this two times. The first time setups up preferred encodings at
	 the top of the list. The next handles everything else. */
	NSArray *favoredEncodings = @[@"Unicode", @"Western", @"Central European"];

	[self populateEncodingPopup:encodingsToAdd preferredEncodings:favoredEncodings ignoreFavored:NO];

	if ([RZUserDefaults() boolForKey:@"Server Properties Window Sheet -> Include Advanced Encodings"]) {
		[self populateEncodingPopup:encodingsToAdd preferredEncodings:favoredEncodings ignoreFavored:YES];
	}
}

- (void)populateEncodingPopup:(NSArray<NSString *> *)encodingsToAdd preferredEncodings:(NSArray<NSString *> *)favoredEncodings ignoreFavored:(BOOL)ignoreFavored
{
	NSString *encodingPrefixPrevious = nil;

	for (NSString *encoding in encodingsToAdd) {
		NSInteger parenthesisPosition = [encoding stringPosition:@" ("];

		if (parenthesisPosition <= 0) {
			continue;
		}

		NSString *encodingPrefix = [encoding substringToIndex:parenthesisPosition];

		if (ignoreFavored && [favoredEncodings containsObject:encodingPrefix]) {
			continue;
		} else if (ignoreFavored == NO && [favoredEncodings containsObject:encodingPrefix] == NO) {
			continue;
		}

		if (encodingPrefixPrevious == nil || [encodingPrefix isEqualToString:encodingPrefixPrevious] == NO) {
			encodingPrefixPrevious = encodingPrefix;

			[self.primaryEncodingButton.menu addItem:[NSMenuItem separatorItem]];

			[self.fallbackEncodingButton.menu addItem:[NSMenuItem separatorItem]];
		}

		[self.primaryEncodingButton addItemWithTitle:encoding];

		[self.fallbackEncodingButton addItemWithTitle:encoding];
	}
}

#pragma mark -
#pragma mark Initialization Handler

- (void)start
{
	[self startWithSelection:TDCServerPropertiesSheetSelectionDefault context:nil];
}

- (void)startWithSelection:(TDCServerPropertiesSheetSelection)selection context:(nullable id)context
{
	[self startSheet];

	[self navigateToSelection:selection];

	switch (selection) {
		case TDCServerPropertiesSheetSelectionNewIgnoreEntry:
		{
			if ([context isKindOfClass:[NSString class]]) {
				[self.addressBookPane addIgnoreEntryWithHostmask:context];
			} else if ([context isKindOfClass:[IRCAddressBookEntry class]]) {
				[self.addressBookPane editEntry:context];
			}

			break;
		}
		default:
		{
			break;
		}
	}
}

- (void)navigateToSelection:(TDCServerPropertiesSheetSelection)selection
{
	if (selection == TDCServerPropertiesSheetSelectionDefault) {
		selection = TDCServerPropertiesSheetSelectionGeneral;
	} else if (selection == TDCServerPropertiesSheetSelectionNewIgnoreEntry) {
		selection = TDCServerPropertiesSheetSelectionAddressBook;
	}

	[self.navigationOutlineView navigateToItemWithIdentifier:selection];

	[self.sheet recalculateKeyViewLoop];
}

- (void)closeChildSheets
{
	for (TDCServerPropertiesPane *pane in self.panes) {
		[pane closeChildSheets];
	}
}

- (void)ok:(nullable id)sender
{
	if ([self okOrError] == NO) {
		return;
	}

	[self removeConfigurationDidChangeObserver];

	[self closeChildSheets];

	[self saveConfig];

	id delegate = self.delegate;

	if ([delegate respondsToSelector:@selector(serverPropertiesSheet:onOk:)]) {
		[delegate serverPropertiesSheet:self onOk:[self.config copy]];
	}

	[super ok:nil];
}

- (BOOL)okOrError
{
	TDCServerPropertiesSheetSelection selection = self.navigationOutlineView.selectedItem.identifier;

	/* We want to show the error for the visible view first so that
	 the user isn't jerked around. */
	if ([self okOrErrorForSelection:selection] == NO) {
		return NO;
	}

	NSMutableArray<TDCServerPropertiesPane *> *panes = [self.panes mutableCopy];

	NSUInteger visiblePaneIndex =
	[panes indexOfObjectPassingTest:^BOOL(TDCServerPropertiesPane *pane, NSUInteger index, BOOL *stop) {
		return (pane.selection == selection);
	}];

	if (visiblePaneIndex != NSNotFound) {
		TDCServerPropertiesPane *visiblePane = panes[visiblePaneIndex];

		[panes removeObjectAtIndex:visiblePaneIndex];

		[panes insertObject:visiblePane atIndex:0];
	}

	for (TDCServerPropertiesPane *pane in panes) {
		id field = pane.firstInvalidField;

		if (field) {
			[self showValidationErrorForField:field inSelection:pane.selection];

			return NO;
		}
	}

	NSArray *remainingSelections =
	@[
	  @(TDCServerPropertiesSheetSelectionDisconnectMessages),
	  @(TDCServerPropertiesSheetSelectionProxyServer),
	  ];

	for (NSNumber *selectionRemaining in remainingSelections) {
		if (selectionRemaining.integerValue == selection) {
			continue;
		}

		if ([self okOrErrorForSelection:selectionRemaining.integerValue] == NO) {
			return NO;
		}
	}

	return YES;
}

- (BOOL)okOrErrorForSelection:(TDCServerPropertiesSheetSelection)selection
{
	switch (selection) {
		case TDCServerPropertiesSheetSelectionDisconnectMessages:
		{
			if ([self okOrErrorForTextField:self.normalLeavingCommentTextField inSelection:selection] == NO) {
				return NO;
			} else if ([self okOrErrorForTextField:self.sleepModeQuitMessageTextField inSelection:selection] == NO) {
				return NO;
			}

			break;
		}

		case TDCServerPropertiesSheetSelectionProxyServer:
		{
			if ([self okOrErrorForTextField:self.proxyAddressTextField inSelection:selection] == NO) {
				return NO;
			} else if ([self okOrErrorForTextField:self.proxyPortTextField inSelection:selection] == NO) {
				return NO;
			}

			break;
		}
		default:
		{
			break;
		}
	} // switch()

	return YES;
}

- (BOOL)okOrErrorForTextField:(TVCValidatedTextField *)textField inSelection:(TDCServerPropertiesSheetSelection)selection
{
	if (textField.valueIsValid) {
		return YES;
	}

	[self showValidationErrorForField:textField inSelection:selection];

	return NO;
}

/* A validated text field or combo box */
- (void)showValidationErrorForField:(id)field inSelection:(TDCServerPropertiesSheetSelection)selection
{
	[self navigateToSelection:selection];

	/* Give navigation time to settle before trying to attach popover */
	XRPerformBlockAsynchronouslyOnMainQueue(^{
		[field showValidationErrorPopover];
	});
}

- (void)cancel:(nullable id)sender
{
	[self removeConfigurationDidChangeObserver];

	[self closeChildSheets];

	[super cancel:nil];
}

- (void)addConfigurationDidChangeObserver
{
	if (self.client == nil) {
		return;
	}

	[RZNotificationCenter() addObserver:self
							   selector:@selector(underlyingConfigurationChanged:)
								   name:IRCClientConfigurationWasUpdatedNotification
								 object:self.client];
}

- (void)removeConfigurationDidChangeObserver
{
	[RZNotificationCenter() removeObserver:self];
}

- (void)underlyingConfigurationChanged:(NSNotification *)notification
{
	NSWindow *window = self.sheet.deepestWindow;
	
	[TDCAlert alertSheetWithWindow:window
							  body:TXTLS(@"TDCServerPropertiesSheet[oz4-kb]")
							 title:TXTLS(@"TDCServerPropertiesSheet[bzh-il]")
					 defaultButton:TXTLS(@"Prompts[mvh-ms]")
				   alternateButton:TXTLS(@"Prompts[99q-gg]")
					   otherButton:nil
				   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id underlyingAlert) {
					   if (buttonClicked != TDCAlertResponseDefault) {
						   return;
					   }

					   /* A new sheet: this one, closed and started again, lost its
						observers and table data, and loaded every list twice */
					   id delegate = self.delegate;

					   if ([delegate respondsToSelector:@selector(serverPropertiesSheetWantsReload:)]) {
						   [delegate serverPropertiesSheetWantsReload:self];
					   }
				   }];
}

- (void)loadConfig
{
	/* ZNC Bouncer */
	self.zncIgnoreConfiguredAutojoinCheck.state = self.config.zncIgnoreConfiguredAutojoin;
	self.zncIgnorePlaybackNotificationsCheck.state = self.config.zncIgnorePlaybackNotifications;
	self.zncOnlyPlaybackLatestCheck.state = self.config.zncOnlyPlaybackLatest;

	/* Network Socket */
	IRCConnectionAddressType addressType = self.config.addressType;

	self.connectionIPv4AddressTypeCheck.state = (addressType == IRCConnectionAddressTypeIPv4);
	self.connectionIPv6AddressTypeCheck.state = (addressType == IRCConnectionAddressTypeIPv6);
	self.connectionDefaultAddressTypeCheck.state = (addressType == IRCConnectionAddressTypeDefault);

	self.pongTimerCheck.state = self.config.performPongTimer;
	self.performDisconnectOnPongTimerCheck.state = self.config.performDisconnectOnPongTimer;

	self.disconnectOnReachabilityChangeCheck.state = self.config.performDisconnectOnReachabilityChange;

	self.validateServerCertificateChainCheck.state = self.config.validateServerCertificateChain;

	[self.preferredCipherSuitesButton selectItemWithTag:self.config.cipherSuites];

	/* Messages */
	self.normalLeavingCommentTextField.stringValue = self.config.normalLeavingComment;

	self.sleepModeQuitMessageTextField.stringValue = self.config.sleepModeLeavingComment;

	/* Encoding */
	NSString *primaryEncodingTitle = [self.encodingList firstKeyForObject:@(self.config.primaryEncoding)];

	[self.primaryEncodingButton selectItemWithTitle:primaryEncodingTitle];

	NSString *fallbackEncodingTitle = [self.encodingList firstKeyForObject:@(self.config.fallbackEncoding)];

	[self.fallbackEncodingButton selectItemWithTitle:fallbackEncodingTitle];

	/* Proxy Server */
	[self.proxyTypeButton selectItemWithTag:self.config.proxyType];

	self.proxyAddressTextField.stringValue = (self.config.proxyAddress ?: @"");
	self.proxyPortTextField.integerValue = self.config.proxyPort;
	self.proxyUsernameTextField.stringValue = (self.config.proxyUsername ?: @"");
	self.proxyPasswordTextField.stringValue = (self.config.proxyPassword ?: @"");

	/* Connect Commands */
	NSString *loginCommandsString = [self.config.loginCommands componentsJoinedByString:@"\n"];

	self.connectCommandsField.string = loginCommandsString;

	self.setInvisibleModeOnConnectCheck.state = self.config.setInvisibleModeOnConnect;

	/* Flood Control */
	self.floodControlDelayTimerSliderTempValue = self.config.floodControlDelayTimerInterval;
	self.floodControlMessageCountSliderTempValue = self.config.floodControlMaximumMessages;

	for (TDCServerPropertiesPane *pane in self.panes) {
		[pane loadFromConfig:self.config];
	}

	[self loadConfigPostflight];
}

- (void)loadConfigPostflight
{
	[self preferredCipherSuitesChanged:nil];

	[self proxyTypeChanged:nil];
}

- (void)saveConfig
{
	/* ZNC Bouncer */
	self.config.zncIgnoreConfiguredAutojoin = (self.zncIgnoreConfiguredAutojoinCheck.state == NSControlStateValueOn);
	self.config.zncIgnorePlaybackNotifications = (self.zncIgnorePlaybackNotificationsCheck.state == NSControlStateValueOn);
	self.config.zncOnlyPlaybackLatest = (self.zncOnlyPlaybackLatestCheck.state == NSControlStateValueOn);

	/* Network Socket */
	self.config.performPongTimer = (self.pongTimerCheck.state == NSControlStateValueOn);
	self.config.performDisconnectOnPongTimer = (self.performDisconnectOnPongTimerCheck.state == NSControlStateValueOn);

	self.config.performDisconnectOnReachabilityChange = (self.disconnectOnReachabilityChangeCheck.state == NSControlStateValueOn);

	self.config.validateServerCertificateChain = (self.validateServerCertificateChainCheck.state == NSControlStateValueOn);

	self.config.cipherSuites = self.preferredCipherSuitesButton.selectedTag;

	/* Messages */
	self.config.sleepModeLeavingComment	= self.sleepModeQuitMessageTextField.value;
	self.config.normalLeavingComment = self.normalLeavingCommentTextField.value;

	/* Encoding */
	NSStringEncoding primaryEncoding = [self.encodingList unsignedIntegerForKey:self.primaryEncodingButton.title];

	self.config.primaryEncoding	= primaryEncoding;

	NSStringEncoding fallbackEncoding = [self.encodingList unsignedIntegerForKey:self.fallbackEncodingButton.title];

	self.config.fallbackEncoding = fallbackEncoding;

	/* Proxy Server */
	self.config.proxyType = self.proxyTypeButton.selectedTag;

	self.config.proxyAddress = self.proxyAddressTextField.lowercaseValue;
	self.config.proxyPort = self.proxyPortTextField.integerValue;
	self.config.proxyUsername = self.proxyUsernameTextField.trimmedFirstTokenStringValue;
	self.config.proxyPassword = self.proxyPasswordTextField.trimmedStringValue;

	/* Connect Commands */
	NSString *connectCommandsString = self.connectCommandsField.string;

	NSArray *connectCommands = [connectCommandsString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

	self.config.loginCommands = [connectCommands arrayByRemovingEmptyValues:YES trimming:YES uniquing:NO];

	self.config.setInvisibleModeOnConnect = (self.setInvisibleModeOnConnectCheck.state == NSControlStateValueOn);

	/* Flood Control */
	self.config.floodControlMaximumMessages = self.floodControlMessageCountSlider.integerValue;
	self.config.floodControlDelayTimerInterval = self.floodControlDelayTimerSlider.integerValue;

	for (TDCServerPropertiesPane *pane in self.panes) {
		[pane saveToConfig:self.config];
	}
}

#pragma mark -
#pragma mark Properties

- (NSArray<IRCChannelConfig *> *)channelList
{
	return self.channelsPane.items;
}

#pragma mark -
#pragma mark Actions

- (void)preferredCipherSuitesChanged:(nullable id)sender
{
	NSInteger cipherSuites = self.preferredCipherSuitesButton.selectedTag;

	self.viewListOfPreferredCipherSuitesButton.enabled =
	(cipherSuites != RCMCipherSuiteCollectionNone);
}

- (void)preferredCipherSuitesViewList:(nullable id)sender
{
	NSInteger cipherSuites = self.preferredCipherSuitesButton.selectedTag;

	NSArray *cipherSuitesDescriptions = [RCMSecureTransport descriptionsForCipherListCollection:cipherSuites withProtocol:YES];

	NSString *cipherSuitesDescription = [cipherSuitesDescriptions componentsJoinedByString:@"\n"];

	NSString *cipherSuitesTitle = self.preferredCipherSuitesButton.titleOfSelectedItem;

	[TDCAlert alertSheetWithWindow:self.sheet
							  body:TXTLS(@"TDCServerPropertiesSheet[k50-8n]", cipherSuitesDescription)
							 title:TXTLS(@"TDCServerPropertiesSheet[yko-5g]", cipherSuitesTitle)
					 defaultButton:TXTLS(@"Prompts[c7s-dq]")
				   alternateButton:nil
					   otherButton:nil];
}

- (void)proxyTypeChanged:(nullable id)sender
{
	NSInteger proxyType = self.proxyTypeButton.selectedTag;

	BOOL isSystemSocksProxyEnabled = (proxyType == IRCConnectionProxyTypeAutomatic);
	BOOL isTorBrowserProxyEnabled = (proxyType == IRCConnectionProxyTypeTor);

	BOOL httpsEnabled = (proxyType == IRCConnectionProxyTypeHTTP || proxyType == IRCConnectionProxyTypeHTTPS);
	BOOL socksEnabled = (proxyType == IRCConnectionProxyTypeSocks5);

	BOOL enabled = (httpsEnabled || socksEnabled);

	self.contentViewProxyServerInputView.hidden = (httpsEnabled == NO && socksEnabled == NO);
	self.contentViewProxyServerTorBrowserView.hidden = (isTorBrowserProxyEnabled == NO);
	self.contentViewProxyServerSystemSocksView.hidden = (isSystemSocksProxyEnabled == NO);

	self.proxyAddressTextField.enabled = enabled;
	self.proxyPortTextField.enabled = enabled;

	/* SOCKS5 and HTTP(S) CONNECT proxies can both ask for a username and password */
	self.proxyUsernameTextField.enabled = enabled;
	self.proxyPasswordTextField.enabled = enabled;

	[self.proxyAddressTextField performValidation];
	[self.proxyPortTextField performValidation];
}

- (void)openProxySettingsInSystemPreferences:(nullable id)sender
{
	[TDCPreferencesController openProxySettingsInSystemPreferences];
}

- (void)toggleAdvancedEncodings:(nullable id)sender
{
	NSString *primaryEncoding = self.primaryEncodingButton.titleOfSelectedItem;

	NSString *fallbackEncoding = self.fallbackEncodingButton.titleOfSelectedItem;

	[self populateEncodings];

	NSMenuItem *primaryEncodingItem = nil;

	if (primaryEncoding) {
		primaryEncodingItem = [self.primaryEncodingButton itemWithTitle:primaryEncoding];
	}

	if (primaryEncodingItem == nil) {
		primaryEncoding = [NSString localizedNameOfStringEncoding:TXDefaultPrimaryStringEncoding];
	}

	NSMenuItem *fallbackEncodingItem = nil;

	if (fallbackEncoding) {
		fallbackEncodingItem = [self.fallbackEncodingButton itemWithTitle:fallbackEncoding];
	}

	if (fallbackEncodingItem == nil) {
		fallbackEncoding = [NSString localizedNameOfStringEncoding:TXDefaultFallbackStringEncoding];
	}

	[self.primaryEncodingButton selectItemWithTitle:primaryEncoding];

	[self.fallbackEncodingButton selectItemWithTitle:fallbackEncoding];
}

- (void)preferredInternetProtocolChanged:(nullable id)sender
{
TEXTUAL_IGNORE_DEPRECATION_BEGIN
	/* Changing the property triggers a deprecation log to console
	 which is just unnecessary output when each time we change it. */
	if (self.config.connectionPrefersIPv4) {
		self.config.connectionPrefersIPv4 = NO;
	}
TEXTUAL_IGNORE_DEPRECATION_END

	self.config.addressType = [sender tag];
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	for (TDCServerPropertiesPane *pane in self.panes) {
		[pane tearDown];
	}

	[self.sheet makeFirstResponder:nil];

	id delegate = self.delegate;

	if ([delegate respondsToSelector:@selector(serverPropertiesSheetWillClose:)]) {
		[delegate serverPropertiesSheetWillClose:self];
	}

	[super windowWillClose:note];
}

@end

NS_ASSUME_NONNULL_END
