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

#import "NSViewHelper.h"
#import "TXMasterController.h"
#import "TXMenuController.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TVCMainWindowPrivate.h"
#import "TDCPreferencesPanePrivate.h"

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
#import <Sparkle/Sparkle.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface TDCPreferencesPane ()
@property (nonatomic, assign, readwrite) BOOL reloadingTheme;
@end

@implementation TDCPreferencesPane

- (instancetype)initWithNibName:(NSString *)nibName
{
	NSParameterAssert(nibName != nil);

	if ((self = [super initWithNibName:nibName bundle:[NSBundle mainBundle]])) {
		[RZNotificationCenter() addObserver:self
								   selector:@selector(themeWillReload:)
									   name:TVCMainWindowWillReloadThemeNotification
									 object:nil];

		[RZNotificationCenter() addObserver:self
								   selector:@selector(themeDidReload:)
									   name:TVCMainWindowDidReloadThemeNotification
									 object:nil];

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[RZNotificationCenter() removeObserver:self];
}

- (void)themeWillReload:(NSNotification *)notification
{
	self.reloadingTheme = YES;
}

- (void)themeDidReload:(NSNotification *)notification
{
	self.reloadingTheme = NO;
}

- (void)deactivateColorWells
{
	if (self.viewLoaded) {
		[self deactivateColorWellsInView:self.view];
	}
}

- (void)deactivateColorWellsInView:(NSView *)view
{
	if ([view isKindOfClass:[NSColorWell class]]) {
		[(NSColorWell *)view deactivate];

		return;
	}

	for (NSView *subview in view.subviews) {
		[self deactivateColorWellsInView:subview];
	}
}

/* TDCPreferencesGeneralPane → TDCPreferencesGeneral */
- (instancetype)init
{
	NSString *className = NSStringFromClass([self class]);

	NSParameterAssert([className hasSuffix:@"Pane"]);

	return [self initWithNibName:[className substringToIndex:(className.length - 4)]];
}

- (void)paneWillClose
{

}

- (void)onChangedTheme:(nullable id)sender
{
	[TPCPreferences performReloadAction:(TPCPreferencesReloadActionStyle | TPCPreferencesReloadActionTextDirection)];
}

@end

#pragma mark -
#pragma mark General

@interface TDCPreferencesGeneralPane ()
@property (nonatomic, weak) IBOutlet NSStackView *stackView;
@property (nonatomic, weak) IBOutlet NSView *checkForUpdatesView;
@property (nonatomic, weak) IBOutlet NSButton *checkForUpdatesDontCheck;
@property (nonatomic, weak) IBOutlet NSButton *checkForUpdatesAutomaticallyCheck;
@property (nonatomic, weak) IBOutlet NSButton *checkForUpdatesAutomaticallyDownload;

/* Bound in the nib */
@property (nonatomic, assign) BOOL preventSleepWhileConnected;

- (IBAction)onChangedCheckForUpdates:(nullable id)sender;
- (IBAction)onChangedCheckForBetaUpdates:(nullable id)sender;
@end

@implementation TDCPreferencesGeneralPane

- (void)viewDidLoad
{
	[super viewDidLoad];

#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	[self updateCheckForUpdatesMatrix];
#else
	/* Hide preferences for updates when support is not enabled. */
	[self.stackView setVisibilityPriority:NSStackViewVisibilityPriorityNotVisible
								  forView:self.checkForUpdatesView];
#endif

	[self.view layoutSubtreeIfNeeded];
}

- (BOOL)preventSleepWhileConnected
{
	return [TPCPreferences preventSleepWhileConnected];
}

- (void)setPreventSleepWhileConnected:(BOOL)preventSleepWhileConnected
{
	[TPCPreferences setPreventSleepWhileConnected:preventSleepWhileConnected];
}

/* One choice over two settings: download implies checking */
- (void)updateCheckForUpdatesMatrix
{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	SPUUpdater *updater = masterController().updateController.updater;

	BOOL checks = updater.automaticallyChecksForUpdates;
	BOOL downloads = (checks && updater.automaticallyDownloadsUpdates);

	self.checkForUpdatesAutomaticallyDownload.state = downloads;
	self.checkForUpdatesAutomaticallyCheck.state = (checks && downloads == NO);
	self.checkForUpdatesDontCheck.state = (checks == NO);
#endif
}

- (void)onChangedCheckForUpdates:(nullable id)sender
{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	SPUUpdater *updater = masterController().updateController.updater;

	BOOL downloads = (sender == self.checkForUpdatesAutomaticallyDownload);
	BOOL checks = (downloads || sender == self.checkForUpdatesAutomaticallyCheck);

	updater.automaticallyChecksForUpdates = checks;
	updater.automaticallyDownloadsUpdates = downloads;

	[self updateCheckForUpdatesMatrix];
#endif
}

- (void)onChangedCheckForBetaUpdates:(nullable id)sender
{
#if TEXTUAL_BUILT_WITH_SPARKLE_ENABLED == 1
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionSparkleFrameworkFeedURL];

	if ([TPCPreferences receiveBetaUpdates]) {
		[menuController() checkForUpdates:nil];
	}
#endif
}

@end

#pragma mark -
#pragma mark Controls

@interface TDCPreferencesControlsPane ()
- (IBAction)onChangedInputHistoryScheme:(nullable id)sender;
- (IBAction)onChangedMainInputTextViewFontSize:(nullable id)sender;
- (IBAction)onChangedMainWindowSegmentedController:(nullable id)sender;
@end

@implementation TDCPreferencesControlsPane

- (void)onChangedInputHistoryScheme:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionInputHistoryScope];
}

- (void)onChangedMainInputTextViewFontSize:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionTextFieldFontSize];
}

- (void)onChangedMainWindowSegmentedController:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionTextFieldSegmentedControllerOrigin];
}

@end

#pragma mark -
#pragma mark Command Scope

@interface TDCPreferencesCommandScopePane ()
@property (nonatomic, weak) IBOutlet NSButton *forwardNoticeToServerConsoleButton;
@property (nonatomic, weak) IBOutlet NSButton *forwardNoticeToSelectedChannelButton;
@property (nonatomic, weak) IBOutlet NSButton *forwardNoticeToQueryButton;

- (IBAction)onChangedForwardNoticeTo:(nullable id)sender;
@end

@implementation TDCPreferencesCommandScopePane

- (void)viewDidLoad
{
	[super viewDidLoad];

	TXNoticeSendLocation location = [TPCPreferences locationToSendNotices];

	self.forwardNoticeToServerConsoleButton.state = (location == TXNoticeSendLocationServerConsole);
	self.forwardNoticeToSelectedChannelButton.state = (location == TXNoticeSendLocationSelectedChannel);
	self.forwardNoticeToQueryButton.state = (location == TXNoticeSendLocationQuery);
}

- (void)onChangedForwardNoticeTo:(nullable id)sender
{
	[TPCPreferences setLocationToSendNotices:[sender tag]];
}

@end

NS_ASSUME_NONNULL_END
