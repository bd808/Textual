/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
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
#import "TPCPathInfoPrivate.h"
#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReload.h"
#import "TPCPreferencesUserDefaults.h"
#import "THOPluginManagerPrivate.h"
#import "IRC.h"
#import "TLOLocalization.h"
#import "TLOpenLink.h"
#import "TVCMainWindowPrivate.h"
#import "TDCAlert.h"
#import "TDCFileTransferDialogPrivate.h"
#import "TDCPreferencesPanePrivate.h"
#import "TDCPreferencesControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

#define _scrollbackVisibleLinesMin	100
#define _scrollbackVisibleLinesMax	15000
#define _inlineMediaWidthMax		2000
#define _inlineMediaWidthMin		40
#define _inlineMediaHeightMax		6000
#define _inlineMediaHeightMin		0

#define _fileTransferPortRangeMin			1024
#define _fileTransferPortRangeMax			TXMaximumTCPPort

/* The tags of toolbar items and of the Advanced and Addons menus' items.
 Items in the Advanced menu select the Advanced toolbar item (as Installed
 Addons and plugins select Addons). */
typedef NS_ENUM(NSInteger, TDCPreferencesPaneTag) {
	TDCPreferencesPaneTagGeneral = 101,
	TDCPreferencesPaneTagBehavior = 102,
	TDCPreferencesPaneTagNotifications = 103,
	TDCPreferencesPaneTagHighlights = 104,
	TDCPreferencesPaneTagInterface = 105,
	TDCPreferencesPaneTagStyle = 106,
	TDCPreferencesPaneTagControls = 107,
	TDCPreferencesPaneTagAdvanced = 108,
	TDCPreferencesPaneTagAddons = 109,

	TDCPreferencesPaneTagChannelManagement = 108000,
	TDCPreferencesPaneTagCommandScope = 108001,
	TDCPreferencesPaneTagFloodControl = 108002,
	TDCPreferencesPaneTagIncomingData = 108003,
	TDCPreferencesPaneTagFileTransfers = 108005,
	TDCPreferencesPaneTagInlineMedia = 108006,
	TDCPreferencesPaneTagLogLocation = 108007,
	TDCPreferencesPaneTagDefaultIdentity = 108008,
	TDCPreferencesPaneTagDefaultIRCopMessages = 108009,

	TDCPreferencesPaneTagInstalledAddons = 109000,

	TDCPreferencesPaneTagFirstPlugin = 995 // plus the plugin's index
};

#define _unsignedIntegerString(_value_)			[NSString stringWithUnsignedInteger:_value_]

@interface TDCPreferencesController ()
@property (nonatomic, strong) IBOutlet NSArrayController *installedScriptsController;
@property (nonatomic, weak) IBOutlet NSPopUpButton *transcriptFolderButton;
@property (nonatomic, weak) IBOutlet NSPopUpButton *fileTransferDownloadDestinationButton;
@property (nonatomic, weak) IBOutlet NSTableView *installedScriptsTable;
@property (nonatomic, weak) IBOutlet NSTextField *fileTransferManuallyEnteredIPAddressTextField;
@property (nonatomic, strong) IBOutlet NSView *contentViewInstalledAddons;
@property (nonatomic, strong) IBOutlet NSView *contentViewFileTransfers;
@property (nonatomic, strong) IBOutlet NSView *contentViewInlineMedia;
@property (nonatomic, strong) IBOutlet NSView *contentViewLogLocation;

@property (nonatomic, strong) IBOutlet NSView *contentViewHiddenPreferences;
@property (nonatomic, weak) IBOutlet NSButton *inlineMediaEnabledButton;
@property (nonatomic, strong) IBOutlet NSToolbar *navigationToolbar;
@property (nonatomic, strong) IBOutlet NSMenu *installedAddonsMenu;
@property (nonatomic, assign) BOOL reloadingTheme;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, TDCPreferencesPane *> *panes; // tag → section, once shown

- (IBAction)onChangedInlineMediaOption:(nullable id)sender;
- (IBAction)onChangedScrollbackVisibleLimit:(nullable id)sender;
- (IBAction)onChangedTheme:(nullable id)sender;
- (IBAction)onChangedTranscriptFolder:(nullable id)sender;
- (IBAction)onChangedUserListModeColor:(nullable id)sender;
- (IBAction)onFileTransferDownloadDestinationFolderChanged:(nullable id)sender;
- (IBAction)onFileTransferIPAddressDetectionMethodChanged:(nullable id)sender;
- (IBAction)onOpenPathToScripts:(nullable id)sender;
- (IBAction)onPrefPaneSelected:(nullable id)sender;

@end

/* The colour wells' bindings: reads both formats colours are stored in
 (keyed archives, and NSArchiver data in older defaults, as
 -[NSUserDefaults colorForKey:] does) and writes a secure keyed archive */
@interface TDCPreferencesColorTransformer : NSValueTransformer
@end

@implementation TDCPreferencesColorTransformer

+ (Class)transformedValueClass
{
	return [NSColor class];
}

+ (BOOL)allowsReverseTransformation
{
	return YES;
}

- (nullable id)transformedValue:(nullable id)value
{
	if ([value isKindOfClass:[NSData class]] == NO) {
		return nil;
	}

	return [NSKeyedUnarchiver legacyCompatUnarchivedObjectOfClass:[NSColor class] fromData:value];
}

- (nullable id)reverseTransformedValue:(nullable id)value
{
	if ([value isKindOfClass:[NSColor class]] == NO) {
		return nil;
	}

	return [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:YES error:NULL];
}

@end

@implementation TDCPreferencesController

+ (void)initialize
{
	if (self != [TDCPreferencesController class]) {
		return;
	}

	/* Before the nib, whose colour wells name it */
	[NSValueTransformer setValueTransformer:[TDCPreferencesColorTransformer new]
									forName:@"TDCPreferencesColorTransformer"];
}

- (instancetype)init
{
	if ((self = [super initWithWindowNibName:@"TDCPreferences" owner:self])) {
		(void)self.window; // Loads the nib

		return self;
	}

	return nil;
}

- (void)windowDidLoad
{
	[super windowDidLoad];

	self.panes = [NSMutableDictionary dictionary];

	[self setUpToolbarItemsAndMenus];

	[self updateFileTransferDownloadDestinationFolder];
	[self updateInlineMediaEnabled];
	[self updateTranscriptFolder];

	[self onFileTransferIPAddressDetectionMethodChanged:nil];

	self.installedScriptsTable.sortDescriptors = @[
		[NSSortDescriptor sortDescriptorWithKey:@"string" ascending:YES selector:@selector(caseInsensitiveCompare:)]
	];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(onThemeWillReload:)
								   name:TVCMainWindowWillReloadThemeNotification
								 object:nil];

	[RZNotificationCenter() addObserver:self
							   selector:@selector(onThemeReloadComplete:)
								   name:TVCMainWindowDidReloadThemeNotification
								 object:nil];

	/* Reset from the Interface section */
	[RZUserDefaults() addObserver:self forKeyPath:@"User List Mode Badge Colors -> no mode" options:0 context:NULL];

	[self restoreWindowFrame];
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context
{
	if ([keyPath isEqualToString:@"User List Mode Badge Colors -> no mode"]) {
		[self willChangeValueForKey:@"userListNoModeColor"];
		[self didChangeValueForKey:@"userListNoModeColor"];

		return;
	}

	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark -
#pragma mark Utilities

- (void)show:(TDCPreferencesControllerSelection)selection
{
	switch (selection) {
		case TDCPreferencesControllerSelectionNotifications:
		{
			[self _showPane:[self paneForTag:TDCPreferencesPaneTagNotifications].view selectedItem:TDCPreferencesPaneTagNotifications];

			break;
		}
		case TDCPreferencesControllerSelectionStyle:
		{
			[self _showPane:[self paneForTag:TDCPreferencesPaneTagStyle].view selectedItem:TDCPreferencesPaneTagStyle];

			break;
		}
		case TDCPreferencesControllerSelectionHiddenPreferences:
		{
			[self _showPane:self.contentViewHiddenPreferences selectedItem:TDCPreferencesPaneTagAdvanced];

			break;
		}
		default:
		{
			[self _showPane:[self paneForTag:TDCPreferencesPaneTagGeneral].view selectedItem:TDCPreferencesPaneTagGeneral];

			break;
		}
	}
}

- (void)_showPane:(NSView *)view selectedItem:(NSInteger)selectedItem
{
	[self firstPane:view selectedItem:selectedItem];

	[self.window makeKeyAndOrderFront:nil];
}

#pragma mark -
#pragma mark NSToolbar Delegates

 - (void)setUpToolbarItemsAndMenus
{
	NSArray *plugins = sharedPluginManager().pluginsWithPreferencePanes;

	if (plugins.count > 0) {
		[self.installedAddonsMenu addItem:[NSMenuItem separatorItem]];
	}

	[plugins enumerateObjectsUsingBlock:^(THOPluginItem *plugin, NSUInteger index, BOOL *stop) {
		NSUInteger tagIndex = (index + TDCPreferencesPaneTagFirstPlugin);

		NSMenuItem *pluginMenu = [NSMenuItem menuItemWithTitle:plugin.pluginPreferencesPaneMenuItemTitle
														target:self
														action:@selector(onPrefPaneSelected:)];

		pluginMenu.tag = tagIndex;

		[self.installedAddonsMenu addItem:pluginMenu];
	}];
}

 - (void)onPrefPaneSelected:(nullable id)sender
{
	NSInteger tag = [sender tag];

	TDCPreferencesPane *pane = [self paneForTag:tag];

	if (pane) {
		[self firstPane:pane.view selectedItem:[self toolbarItemForTag:tag]];

		return;
	}

#define _de(matchTag, view)		\
		case (matchTag): {	\
			[self firstPane:(view) selectedItem:[self toolbarItemForTag:(matchTag)]];	\
			break;		\
		}

	switch (tag) {
		_de(TDCPreferencesPaneTagFileTransfers, self.contentViewFileTransfers)
		_de(TDCPreferencesPaneTagInlineMedia, self.contentViewInlineMedia)
		_de(TDCPreferencesPaneTagLogLocation, self.contentViewLogLocation)
		_de(TDCPreferencesPaneTagInstalledAddons, self.contentViewInstalledAddons)

		default:
		{
			if (tag < TDCPreferencesPaneTagFirstPlugin) {
				break;
			}

			NSUInteger pluginIndex = (tag - TDCPreferencesPaneTagFirstPlugin);

			THOPluginItem *plugin = sharedPluginManager().pluginsWithPreferencePanes[pluginIndex];

			/* Shared by every Preferences window (the plugin made it once) */
			NSView *preferencesView = plugin.pluginPreferencesPaneView;

			[self firstPane:preferencesView selectedItem:TDCPreferencesPaneTagAddons];

			break;
		}
	}

#undef _de
}

/* The section shown for a tag, made the first time; nil for one still in
 TDCPreferences.xib or a plugin's */
- (nullable TDCPreferencesPane *)paneForTag:(TDCPreferencesPaneTag)tag
{
	TDCPreferencesPane *pane = self.panes[@(tag)];

	if (pane) {
		return pane;
	}

#define _nib(_name_)	[[TDCPreferencesPane alloc] initWithNibName:@"TDCPreferences" _name_]

	switch (tag) {
		case TDCPreferencesPaneTagGeneral: { pane = [TDCPreferencesGeneralPane new]; break; }
		case TDCPreferencesPaneTagBehavior: { pane = _nib(@"Behavior"); break; }
		case TDCPreferencesPaneTagControls: { pane = [TDCPreferencesControlsPane new]; break; }
		case TDCPreferencesPaneTagChannelManagement: { pane = _nib(@"ChannelManagement"); break; }
		case TDCPreferencesPaneTagCommandScope: { pane = [TDCPreferencesCommandScopePane new]; break; }
		case TDCPreferencesPaneTagHighlights: { pane = [TDCPreferencesHighlightsPane new]; break; }
		case TDCPreferencesPaneTagNotifications: { pane = [TDCPreferencesNotificationsPane new]; break; }
		case TDCPreferencesPaneTagInterface: { pane = [TDCPreferencesInterfacePane new]; break; }
		case TDCPreferencesPaneTagStyle: { pane = [TDCPreferencesStylePane new]; break; }
		case TDCPreferencesPaneTagFloodControl: { pane = _nib(@"FloodControl"); break; }
		case TDCPreferencesPaneTagIncomingData: { pane = _nib(@"IncomingData"); break; }
		case TDCPreferencesPaneTagDefaultIdentity: { pane = _nib(@"DefaultIdentity"); break; }
		case TDCPreferencesPaneTagDefaultIRCopMessages: { pane = _nib(@"DefaultIRCopMessages"); break; }
		default: { return nil; }
	}

#undef _nib

	self.panes[@(tag)] = pane;

	return pane;
}

- (TDCPreferencesPaneTag)toolbarItemForTag:(NSInteger)tag
{
	if (tag == TDCPreferencesPaneTagInstalledAddons) {
		return TDCPreferencesPaneTagAddons;
	} else if (tag >= TDCPreferencesPaneTagChannelManagement && tag < TDCPreferencesPaneTagInstalledAddons) {
		return TDCPreferencesPaneTagAdvanced;
	}

	return tag;
}

- (void)firstPane:(NSView *)view selectedItem:(NSInteger)selectedItem
{
	[self.window replaceContentView:view];

	if (selectedItem >= 0) {
		self.navigationToolbar.selectedItemIdentifier = _unsignedIntegerString(selectedItem);
	} else {
		self.navigationToolbar.selectedItemIdentifier = nil;
	}
}

- (void)restoreWindowFrame
{
	NSWindow *window = self.window;

	[window saveSizeAsDefault];

	[window restoreWindowStateForClass:self.class];
}

- (void)saveWindowFrame
{
	NSWindow *window = self.window;

	[window restoreDefaultSizeAndDisplay:NO];

	[window saveWindowStateForClass:self.class];
}

#pragma mark -
#pragma mark KVC Properties

- (NSArray<NSDictionary *> *)installedScripts
{
	NSMutableArray *scriptsInstalled = [NSMutableArray array];

	[scriptsInstalled addObjectsFromArray:sharedPluginManager().supportedAppleScriptCommands];
	[scriptsInstalled addObjectsFromArray:sharedPluginManager().supportedUserInputCommands];

	return scriptsInstalled.stringArrayControllerObjects;
}

- (NSString *)scrollbackVisibleLimit
{
	return _unsignedIntegerString([TPCPreferences scrollbackVisibleLimit]);
}

- (void)setScrollbackVisibleLimit:(NSString *)value
{
	[TPCPreferences setScrollbackVisibleLimit:value.integerValue];
}

- (NSString *)inlineMediaMaxWidth
{
	return _unsignedIntegerString([TPCPreferences inlineMediaMaxWidth]);
}

- (NSString *)inlineMediaMaxHeight
{
	return _unsignedIntegerString([TPCPreferences inlineMediaMaxHeight]);
}

- (void)setInlineMediaMaxWidth:(NSString *)value
{
	[TPCPreferences setInlineMediaMaxWidth:value.integerValue];
}

- (void)setInlineMediaMaxHeight:(NSString *)value
{
	[TPCPreferences setInlineMediaMaxHeight:value.integerValue];
}

- (NSString *)fileTransferPortRangeStart
{
	return _unsignedIntegerString([TPCPreferences fileTransferPortRangeStart]);
}

- (NSString *)fileTransferPortRangeEnd
{
	return _unsignedIntegerString([TPCPreferences fileTransferPortRangeEnd]);
}

- (void)setFileTransferPortRangeStart:(NSString *)value
{
	[TPCPreferences setFileTransferPortRangeStart:value.integerValue];
}

- (void)setFileTransferPortRangeEnd:(NSString *)value
{
	[TPCPreferences setFileTransferPortRangeEnd:value.integerValue];
}

- (BOOL)appNapEnabled
{
	return [TPCPreferences appNapEnabled];
}

- (void)setAppNapEnabled:(BOOL)appNapEnabled
{
	[TPCPreferences setAppNapEnabled:appNapEnabled];
}

- (NSColor *)userListNoModeColor
{
	NSColor *value = [RZUserDefaults() colorForKey:@"User List Mode Badge Colors -> no mode"];

	if (value == nil) {
		value = [NSColor clearColor];
	}

	return value;
}

- (void)setUserListNoModeColor:(NSColor *)userListNoModeColor
{
	NSColor *newValue = userListNoModeColor;

	if ([newValue isEqual:[NSColor clearColor]]) {
		newValue = nil;
	}

	[RZUserDefaults() setColor:newValue
						forKey:@"User List Mode Badge Colors -> no mode"];
}

- (BOOL)logTranscript
{
	return [TPCPreferences logToDisk];
}

- (void)setLogTranscript:(BOOL)logTranscript
{
	[TPCPreferences setLogToDisk:logTranscript];

	/* Turned off: closes the log files that are open */
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionLogTranscripts];
}

- (BOOL)inlineMediaLimitToBasics
{
	return [TPCPreferences inlineMediaLimitToBasics];
}

- (void)setInlineMediaLimitToBasics:(BOOL)inlineMediaLimitToBasics
{
	[TPCPreferences setInlineMediaLimitToBasics:inlineMediaLimitToBasics];

	[self willChangeValueForKey:@"inlineMediaLimitBasicsToFiles"];
	[self didChangeValueForKey:@"inlineMediaLimitBasicsToFiles"];
}

- (BOOL)inlineMediaLimitBasicsToFiles
{
	/* Show value as enabled when basics is disabled */
	if ([TPCPreferences inlineMediaLimitToBasics] == NO) {
		return NO; // UI negates bool so return NO for YES
	}

	return [TPCPreferences inlineMediaLimitBasicsToFiles];
}

- (void)setInlineMediaLimitBasicsToFiles:(BOOL)inlineMediaLimitBasicsToFiles
{
	[TPCPreferences setInlineMediaLimitBasicsToFiles:inlineMediaLimitBasicsToFiles];
}

- (BOOL)validateValue:(inout id *)value forKey:(NSString *)key error:(out NSError **)outError
{
	if ([key isEqualToString:@"scrollbackVisibleLimit"]) {
		NSInteger valueInteger = [*value integerValue];

		if (valueInteger < _scrollbackVisibleLinesMin && valueInteger != 0) {
			*value = _unsignedIntegerString(_scrollbackVisibleLinesMin);
		} else if (valueInteger > _scrollbackVisibleLinesMax) {
			*value = _unsignedIntegerString(_scrollbackVisibleLinesMax);
		}
	} else if ([key isEqualToString:@"inlineMediaMaxWidth"]) {
		NSInteger valueInteger = [*value integerValue];

		if (valueInteger < _inlineMediaWidthMin) {
			*value = _unsignedIntegerString(_inlineMediaWidthMin);
		} else if (_inlineMediaWidthMax < valueInteger) {
			*value = _unsignedIntegerString(_inlineMediaWidthMax);
		}
	} else if ([key isEqualToString:@"inlineMediaMaxHeight"]) {
		NSInteger valueInteger = [*value integerValue];

		if (valueInteger < _inlineMediaHeightMin) {
			*value = _unsignedIntegerString(_inlineMediaHeightMin);
		} else if (_inlineMediaHeightMax < valueInteger) {
			*value = _unsignedIntegerString(_inlineMediaHeightMax);
		}
	} else if ([key isEqualToString:@"fileTransferPortRangeStart"]) {
		NSInteger valueInteger = [*value integerValue];

		NSUInteger valueRangeEnd = [TPCPreferences fileTransferPortRangeEnd];

		if (valueInteger < _fileTransferPortRangeMin) {
			*value = _unsignedIntegerString(_fileTransferPortRangeMin);
		} else if (_fileTransferPortRangeMax < valueInteger) {
			*value = _unsignedIntegerString(_fileTransferPortRangeMax);
		}

		valueInteger = [*value integerValue];

		if (valueInteger > valueRangeEnd) {
			*value = _unsignedIntegerString(valueRangeEnd);
		}
	} else if ([key isEqualToString:@"fileTransferPortRangeEnd"]) {
		NSInteger valueInteger = [*value integerValue];

		NSUInteger valueRangeStart = [TPCPreferences fileTransferPortRangeStart];

		if (valueInteger < _fileTransferPortRangeMin) {
			*value = _unsignedIntegerString(_fileTransferPortRangeMin);
		} else if (_fileTransferPortRangeMax < valueInteger) {
			*value = _unsignedIntegerString(_fileTransferPortRangeMax);
		}

		valueInteger = [*value integerValue];

		if (valueInteger < valueRangeStart) {
			*value = _unsignedIntegerString(valueRangeStart);
		}
	}

	return YES;
}

#pragma mark -
#pragma mark File Transfer Destination Folder Popup

- (void)updateFileTransferDownloadDestinationFolder
{
	TDCFileTransferDialog *transferController = [TXSharedApplication sharedFileTransferDialog];

	NSURL *path = transferController.downloadDestinationURL;

	NSMenuItem *item = [self.fileTransferDownloadDestinationButton itemAtIndex:0];

	if (path == nil) {
		item.image = nil;

		item.title = TXTLS(@"TDCPreferencesController[721-ie]");
	} else {
		NSImage *icon = [RZWorkspace() iconForFile:path.path];

		item.image = icon;

		icon.size = NSMakeSize(16, 16);

		item.title = path.lastPathComponent;
	}
}

- (void)onFileTransferDownloadDestinationFolderChanged:(nullable id)sender
{
	TDCFileTransferDialog *transferController = [TXSharedApplication sharedFileTransferDialog];

	if (self.fileTransferDownloadDestinationButton.selectedTag == 2) {
		NSOpenPanel *d = [NSOpenPanel openPanel];

		d.allowsMultipleSelection = NO;
		d.canChooseDirectories = YES;
		d.canChooseFiles = NO;
		d.canCreateDirectories = YES;
		d.resolvesAliases = YES;

		d.prompt = TXTLS(@"Prompts[xne-79]");

		[d beginSheetModalForWindow:self.window completionHandler:^(NSInteger returnCode) {
			[self.fileTransferDownloadDestinationButton selectItemAtIndex:0];

			if (returnCode != NSModalResponseOK) {
				return;
			}

			NSURL *path = d.URLs[0];

			NSError *bookmarkError = nil;

			NSData *bookmark = [path bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
							  includingResourceValuesForKeys:nil
											   relativeToURL:nil
													   error:&bookmarkError];

			/* Keep the folder that was set */
			if (bookmark == nil) {
				LogToConsoleError("Error creating bookmark for URL ('%{public}@'): %{public}@",
					path.standardizedTildePath, bookmarkError.localizedDescription);

				return;
			}

			[transferController setDownloadDestinationBookmark:bookmark];

			[self updateFileTransferDownloadDestinationFolder];
		}];
	}
	else if (self.fileTransferDownloadDestinationButton.selectedTag == 3)
	{
		[self.fileTransferDownloadDestinationButton selectItemAtIndex:0];

		[transferController setDownloadDestinationBookmark:nil];

		[self updateFileTransferDownloadDestinationFolder];
	}
}

#pragma mark -
#pragma mark Transcript Folder Popup

- (void)updateTranscriptFolder
{
	NSURL *path = [TPCPathInfo transcriptFolderURL];

	NSMenuItem *item = [self.transcriptFolderButton itemAtIndex:0];

	if (path == nil) {
		item.image = nil;

		item.title = TXTLS(@"TDCPreferencesController[70s-c6]");
	} else {
		NSImage *icon = [RZWorkspace() iconForFile:path.path];

		item.image = icon;

		icon.size = NSMakeSize(16, 16);

		item.title = path.lastPathComponent;
	}
}

- (void)onChangedTranscriptFolder:(nullable id)sender
{
	if (self.transcriptFolderButton.selectedTag == 2) {
		NSOpenPanel *d = [NSOpenPanel openPanel];

		d.allowsMultipleSelection = NO;
		d.canChooseDirectories = YES;
		d.canChooseFiles = NO;
		d.canCreateDirectories = YES;
		d.resolvesAliases = YES;

		d.prompt = TXTLS(@"Prompts[xne-79]");

		[d beginSheetModalForWindow:self.window completionHandler:^(NSInteger returnCode) {
			[self.transcriptFolderButton selectItemAtIndex:0];

			if (returnCode != NSModalResponseOK) {
				return;
			}

			NSURL *path = d.URLs[0];

			NSError *bookmarkError = nil;

			NSData *bookmark = [path bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
							  includingResourceValuesForKeys:nil
											   relativeToURL:nil
													   error:&bookmarkError];

			if (bookmark == nil) {
				LogToConsoleError("Error creating bookmark for URL ('%{public}@'): %{public}@",
					path.standardizedTildePath, bookmarkError.localizedDescription);

				return;
			}

			[self setTranscriptFolderURL:bookmark];
		}];
	}
	else if (self.transcriptFolderButton.selectedTag == 3)
	{
		[self.transcriptFolderButton selectItemAtIndex:0];

		[self setTranscriptFolderURL:nil];
	}
}

- (void)setTranscriptFolderURL:(nullable NSData *)transcriptFolderURL
{
	[TPCPathInfo setTranscriptFolderURL:transcriptFolderURL];

	[TPCPreferences performReloadAction:TPCPreferencesReloadActionLogTranscripts];

	[self updateTranscriptFolder];
}

#pragma mark -
#pragma mark Theme

#pragma mark -
#pragma mark Actions

/* Opens Network → (current service) Details → Proxies */
+ (void)openProxySettingsInSystemPreferences
{
	NSURL *settingsURL = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.Network-Settings.extension?Proxies"];

	[RZWorkspace() openURL:settingsURL];
}

- (void)updateInlineMediaEnabled
{
	if ([TPCPreferences showInlineMedia]) {
		self.inlineMediaEnabledButton.state = NSControlStateValueOn;
	} else {
		self.inlineMediaEnabledButton.state = NSControlStateValueOff;
	}
}

- (void)onChangedInlineMediaOption:(nullable id)sender
{
	if (self.inlineMediaEnabledButton.state == NSControlStateValueOff) {
		[TPCPreferences setShowInlineMedia:NO];

		[self onChangedTheme:nil];

		return;
	}

	/* Previews go through each server's proxy, so there is nothing to warn about */
	[TPCPreferences setShowInlineMedia:YES];

	[self onChangedTheme:nil];
}

- (void)onChangedTheme:(nullable id)sender
{
	[TPCPreferences performReloadAction:(TPCPreferencesReloadActionStyle | TPCPreferencesReloadActionTextDirection)];
}

- (void)onThemeWillReload:(NSNotification *)notification
{
	self.reloadingTheme = YES;
}

- (void)onThemeReloadComplete:(NSNotification *)notification
{
	self.reloadingTheme = NO;
}

/* The no-mode colour well (Hidden Preferences) */
- (void)onChangedUserListModeColor:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionMemberListUserBadges forKey:@"User List Mode Badge Colors -> no mode"];
}

- (void)onFileTransferIPAddressDetectionMethodChanged:(nullable id)sender
{
	TXFileTransferIPAddressMethodDetection detectionMethod = [TPCPreferences fileTransferIPAddressDetectionMethod];

	self.fileTransferManuallyEnteredIPAddressTextField.enabled = (detectionMethod == TXFileTransferIPAddressMethodManual);
}

- (void)onChangedScrollbackVisibleLimit:(nullable id)sender
{
	[TPCPreferences performReloadAction:TPCPreferencesReloadActionScrollbackVisibleLimit];
}

- (void)onOpenPathToScripts:(nullable id)sender
{
	[RZWorkspace() openURL:[TPCPathInfo applicationSupportURL]];
}

/* An active well keeps its colour from the colour panel, so a reset didn't show */
- (void)deactivateColorWells
{
	NSArray<NSView *> *views = @[
		self.contentViewInstalledAddons, self.contentViewFileTransfers, self.contentViewInlineMedia,
		self.contentViewLogLocation, self.contentViewHiddenPreferences
	];

	for (NSView *view in views) {
		[self deactivateColorWellsInView:view];
	}

	for (TDCPreferencesPane *pane in self.panes.allValues) {
		[pane deactivateColorWells];
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

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[RZNotificationCenter() removeObserver:self];

	[RZUserDefaults() removeObserver:self forKeyPath:@"User List Mode Badge Colors -> no mode"];

	/* The window is released when it closes: the colour panel would
	 still send its changes to an active well in it */
	[self deactivateColorWells];

	for (TDCPreferencesPane *pane in self.panes.allValues) {
		[pane paneWillClose];
	}

	[self saveWindowFrame];

	if ([self.delegate respondsToSelector:@selector(preferencesDialogWillClose:)]) {
		[self.delegate preferencesDialogWillClose:self];
	}
}

@end

NS_ASSUME_NONNULL_END
