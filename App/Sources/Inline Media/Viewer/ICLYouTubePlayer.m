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
#import "IRCClient.h"
#import "IRCConnectionProxyPrivate.h"
#import "ICLYouTubePlayer.h"

NS_ASSUME_NONNULL_BEGIN

/* YouTube asks apps that embed its player to send a Referer naming the app,
 its bundle identifier as an address (else the player shows error 153).
 The release identifier for every build, so it stays the same. */
static NSString * const ICLYouTubePlayerReferer = @"https://com.textualapp.app/";

@interface ICLYouTubePlayer () <WKNavigationDelegate, WKUIDelegate>
@property (nonatomic, copy) NSString *videoIdentifier;
@property (nonatomic, copy) NSURL *embedURL;
@end

@implementation ICLYouTubePlayer

+ (void)playVideo:(NSString *)videoIdentifier startTime:(NSTimeInterval)startTime title:(nullable NSString *)title linkURL:(NSURL *)linkURL client:(nullable IRCClient *)client
{
	NSParameterAssert(videoIdentifier != nil);
	NSParameterAssert(linkURL != nil);

	if ([self isValidVideoIdentifier:videoIdentifier] == NO) {
		return;
	}

	ICLYouTubePlayer *openPlayer = [self openViewerPassingTest:^BOOL(ICLMediaViewer *viewer) {
		return ([viewer isKindOfClass:[ICLYouTubePlayer class]] && [((ICLYouTubePlayer *)viewer).videoIdentifier isEqualToString:videoIdentifier]);
	}];

	if (openPlayer) {
		[openPlayer.window makeKeyAndOrderFront:nil];

		return;
	}

	WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];

	configuration.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];

	if (client) {
		[IRCConnectionProxy applyClientConfig:client.config toWebsiteDataStore:configuration.websiteDataStore];
	}

	/* ▶ was the click: the video starts with its sound */
	configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

	configuration.preferences.elementFullscreenEnabled = YES;

	NSSize contentSize = [self contentSizeForMediaSize:NSMakeSize(854, 480) onScreen:([NSApp mainWindow].screen ?: [NSScreen mainScreen])];

	if (title.length == 0) {
		title = TXLocalizationNotNeeded(@"YouTube");
	}

	ICLYouTubePlayer *player = [[self alloc] initWithLinkURL:linkURL title:title contentSize:contentSize webViewConfiguration:configuration];

	player.videoIdentifier = videoIdentifier;

	player.embedURL = [self embedURLForVideo:videoIdentifier startTime:startTime];

	player.webView.navigationDelegate = player;
	player.webView.UIDelegate = player;

	[player showViewer];
}

+ (BOOL)isValidVideoIdentifier:(NSString *)videoIdentifier
{
	NSParameterAssert(videoIdentifier != nil);

	return (videoIdentifier.length == 11 &&
			[videoIdentifier onlyContainsCharactersFromCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"]]);
}

+ (NSURL *)embedURLForVideo:(NSString *)videoIdentifier startTime:(NSTimeInterval)startTime
{
	NSParameterAssert(videoIdentifier != nil);

	/* YouTube's privacy-enhanced player */
	NSURLComponents *components = [NSURLComponents componentsWithString:@"https://www.youtube-nocookie.com/embed/"];

	components.path = [components.path stringByAppendingString:videoIdentifier];

	/* rel=0: suggestions at the end only from the same channel */
	NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray array];

	[queryItems addObject:[NSURLQueryItem queryItemWithName:@"autoplay" value:@"1"]];
	[queryItems addObject:[NSURLQueryItem queryItemWithName:@"rel" value:@"0"]];

	if (startTime >= 1) {
		[queryItems addObject:[NSURLQueryItem queryItemWithName:@"start" value:[NSString stringWithFormat:@"%.0f", floor(startTime)]]];
	}

	components.queryItems = queryItems;

	return components.URL;
}

- (void)loadContent
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.embedURL];

	[request setValue:ICLYouTubePlayerReferer forHTTPHeaderField:@"Referer"];

	[self.webView loadRequest:request];
}

#pragma mark -
#pragma mark Navigation

/* The player stays the player: a link clicked in it (the title, the logo,
 a suggestion) opens in the browser. Redirects and scripts (a consent page)
 go on in the window. */
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
	NSURL *url = navigationAction.request.URL;

	if (navigationAction.targetFrame.isMainFrame &&
		navigationAction.navigationType == WKNavigationTypeLinkActivated &&
		[url.host isEqualToString:@"www.youtube-nocookie.com"] && [url.path hasPrefix:@"/embed/"])
	{
		decisionHandler(WKNavigationActionPolicyAllow);

		return;
	}

	if (navigationAction.targetFrame.isMainFrame &&
		navigationAction.navigationType == WKNavigationTypeLinkActivated)
	{
		[self _openURLInBrowser:url];

		decisionHandler(WKNavigationActionPolicyCancel);

		return;
	}

	decisionHandler(WKNavigationActionPolicyAllow);
}

/* target="_blank" and window.open() */
- (nullable WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
	[self _openURLInBrowser:navigationAction.request.URL];

	return nil;
}

- (void)_openURLInBrowser:(nullable NSURL *)url
{
	NSString *scheme = url.scheme.lowercaseString;

	if ([scheme isEqualToString:@"https"] == NO && [scheme isEqualToString:@"http"] == NO) {
		return;
	}

	[TLOpenLink open:url];
}

#pragma mark -
#pragma mark Window Delegate

- (void)windowWillClose:(NSNotification *)notification
{
	/* The sound stops with the window */
	[self.webView pauseAllMediaPlaybackWithCompletionHandler:nil];

	[super windowWillClose:notification];
}

@end

NS_ASSUME_NONNULL_END
