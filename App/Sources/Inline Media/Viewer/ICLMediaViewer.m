/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

#import "TLOLocalization.h"
#import "TLOpenLink.h"
#import "ICLMediaSchemeHandlerPrivate.h"
#import "ICLMediaViewer.h"

NS_ASSUME_NONNULL_BEGIN

static NSToolbarItemIdentifier const ICLMediaViewerOpenInBrowserItem = @"ICLMediaViewerOpenInBrowser";
static NSToolbarItemIdentifier const ICLMediaViewerCopyLinkItem = @"ICLMediaViewerCopyLink";

/* Open viewers: they keep themselves alive until closed */
static NSMutableSet<ICLMediaViewer *> *_openViewers = nil;

/* The context menu is the viewer's, not WebKit's (no Open Image in New
 Window, Download Image or Inspect Element) */
@interface ICLMediaViewerWebView : WKWebView
@property (nonatomic, weak) ICLMediaViewer *viewer;
@end

@implementation ICLMediaViewerWebView

- (void)willOpenMenu:(NSMenu *)menu withEvent:(NSEvent *)event
{
	[menu removeAllItems];

	for (NSMenuItem *item in [self.viewer contextMenuItems]) {
		[menu addItem:item];
	}

	[super willOpenMenu:menu withEvent:event];
}

@end

#pragma mark -

@implementation ICLMediaViewer

- (instancetype)initWithLinkURL:(NSURL *)linkURL title:(NSString *)title contentSize:(NSSize)contentSize
{
	return [self initWithLinkURL:linkURL title:title contentSize:contentSize webViewConfiguration:[self webViewConfiguration]];
}

- (instancetype)initWithLinkURL:(NSURL *)linkURL title:(NSString *)title contentSize:(NSSize)contentSize webViewConfiguration:(WKWebViewConfiguration *)webViewConfiguration
{
	NSParameterAssert(linkURL != nil);
	NSParameterAssert(title != nil);
	NSParameterAssert(webViewConfiguration != nil);

	NSWindow *window =
	[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, contentSize.width, contentSize.height)
								styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
								  backing:NSBackingStoreBuffered
									defer:YES];

	window.releasedWhenClosed = NO;
	window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
	window.tabbingMode = NSWindowTabbingModeDisallowed;
	window.contentMinSize = NSMakeSize(240, 160);
	window.title = title;

	/* Above Textual's windows, so it stays in view while you chat (like
	 picture in picture), and hidden while another app is in front */
	window.level = NSFloatingWindowLevel;
	window.hidesOnDeactivate = YES;

	if ((self = [super initWithWindow:window])) {
		self->_linkURL = [linkURL copy];

		window.delegate = self;

		ICLMediaViewerWebView *webView = [[ICLMediaViewerWebView alloc] initWithFrame:NSMakeRect(0, 0, contentSize.width, contentSize.height) configuration:webViewConfiguration];

		webView.viewer = self;

		webView.allowsMagnification = YES;

		webView.autoresizingMask = (NSViewWidthSizable | NSViewHeightSizable);

		window.contentView = webView;

		self->_webView = webView;

		NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"ICLMediaViewer"];

		toolbar.delegate = self;
		toolbar.displayMode = NSToolbarDisplayModeIconOnly;
		toolbar.allowsUserCustomization = NO;

		window.toolbar = toolbar;
		window.toolbarStyle = NSWindowToolbarStyleUnified;

		return self;
	}

	return nil;
}

+ (nullable __kindof ICLMediaViewer *)openViewerPassingTest:(BOOL (NS_NOESCAPE ^)(__kindof ICLMediaViewer *viewer))test
{
	NSParameterAssert(test != nil);

	for (ICLMediaViewer *viewer in _openViewers) {
		if (test(viewer)) {
			return viewer;
		}
	}

	return nil;
}

- (void)showViewer
{
	if (_openViewers == nil) {
		_openViewers = [NSMutableSet set];
	}

	[_openViewers addObject:self];

	[self loadContent];

	NSWindow *window = self.window;

	NSScreen *screen = ([NSApp mainWindow].screen ?: [NSScreen mainScreen]);

	if (screen) {
		NSRect visibleFrame = screen.visibleFrame;

		NSRect frame = window.frame;

		frame.origin.x = (NSMidX(visibleFrame) - (NSWidth(frame) / 2.0));
		frame.origin.y = (NSMidY(visibleFrame) - (NSHeight(frame) / 2.0));

		[window setFrame:frame display:NO];
	}

	[window makeKeyAndOrderFront:nil];
}

+ (NSSize)contentSizeForMediaSize:(NSSize)mediaSize onScreen:(nullable NSScreen *)screen
{
	NSSize maximumSize = NSMakeSize(1200, 800);

	if (screen) {
		/* Room for the title bar and toolbar */
		NSRect visibleFrame = screen.visibleFrame;

		maximumSize = NSMakeSize(floor(NSWidth(visibleFrame) * 0.9), floor((NSHeight(visibleFrame) * 0.9) - 52));
	}

	if (mediaSize.width <= 0 || mediaSize.height <= 0) {
		mediaSize = NSMakeSize(640, 480);
	}

	CGFloat scale = MIN(1.0, MIN((maximumSize.width / mediaSize.width), (maximumSize.height / mediaSize.height)));

	return NSMakeSize(MAX(240, floor(mediaSize.width * scale)), MAX(160, floor(mediaSize.height * scale)));
}

#pragma mark -
#pragma mark Actions

- (IBAction)openInBrowser:(nullable id)sender
{
	[TLOpenLink open:self.linkURL];
}

- (IBAction)copyLink:(nullable id)sender
{
	/* As text, like Copy Link in the chat view */
	RZPasteboard().stringContent = self.linkURL.absoluteString;
}

/* Esc closes it (in full screen, macOS first leaves full screen) */
- (void)cancelOperation:(nullable id)sender
{
	[self.window performClose:sender];
}

#pragma mark -
#pragma mark For Subclasses

- (WKWebViewConfiguration *)webViewConfiguration
{
	WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];

	configuration.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];

	configuration.defaultWebpagePreferences.allowsContentJavaScript = NO;

	[configuration setURLSchemeHandler:[ICLMediaSchemeHandler sharedHandler] forURLScheme:ICLMediaSchemeHandlerScheme];

	return configuration;
}

- (void)loadContent
{

}

- (NSArray<NSToolbarItemIdentifier> *)toolbarItemIdentifiers
{
	return @[ICLMediaViewerOpenInBrowserItem, ICLMediaViewerCopyLinkItem];
}

- (nullable NSToolbarItem *)toolbarItemForIdentifier:(NSToolbarItemIdentifier)identifier
{
	if ([identifier isEqualToString:ICLMediaViewerOpenInBrowserItem]) {
		return [self toolbarItemWithIdentifier:identifier label:TXTLS(@"TVCMainWindow[ivw-ob]") symbolName:@"safari" action:@selector(openInBrowser:)];
	} else if ([identifier isEqualToString:ICLMediaViewerCopyLinkItem]) {
		return [self toolbarItemWithIdentifier:identifier label:TXTLS(@"TVCMainWindow[ivw-cl]") symbolName:@"link" action:@selector(copyLink:)];
	}

	return nil;
}

- (NSToolbarItem *)toolbarItemWithIdentifier:(NSToolbarItemIdentifier)identifier label:(NSString *)label symbolName:(NSString *)symbolName action:(SEL)action
{
	NSParameterAssert(identifier != nil);
	NSParameterAssert(label != nil);
	NSParameterAssert(symbolName != nil);

	NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];

	item.label = label;
	item.toolTip = label;
	item.image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:label];
	item.target = self;
	item.action = action;
	item.bordered = YES;

	return item;
}

- (NSArray<NSMenuItem *> *)contextMenuItems
{
	NSMenuItem *openItem = [[NSMenuItem alloc] initWithTitle:TXTLS(@"TVCMainWindow[ivw-ob]") action:@selector(openInBrowser:) keyEquivalent:@""];

	openItem.target = self;

	NSMenuItem *copyItem = [[NSMenuItem alloc] initWithTitle:TXTLS(@"TVCMainWindow[ivw-cl]") action:@selector(copyLink:) keyEquivalent:@""];

	copyItem.target = self;

	return @[openItem, copyItem];
}

#pragma mark -
#pragma mark Toolbar Delegate

- (NSArray<NSToolbarItemIdentifier> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return [@[NSToolbarFlexibleSpaceItemIdentifier] arrayByAddingObjectsFromArray:[self toolbarItemIdentifiers]];
}

- (NSArray<NSToolbarItemIdentifier> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return [self toolbarDefaultItemIdentifiers:toolbar];
}

- (nullable NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSToolbarItemIdentifier)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	return [self toolbarItemForIdentifier:itemIdentifier];
}

#pragma mark -
#pragma mark Window Delegate

- (void)windowWillClose:(NSNotification *)notification
{
	[self.webView stopLoading];

	/* Released once the window has finished closing */
	dispatch_async(dispatch_get_main_queue(), ^{
		[_openViewers removeObject:self];
	});
}

@end

NS_ASSUME_NONNULL_END
