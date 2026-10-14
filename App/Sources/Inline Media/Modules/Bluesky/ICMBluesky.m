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

#import "ICLHelpers.h"
#import "ICMBluesky.h"

NS_ASSUME_NONNULL_BEGIN

/* Post cards for Bluesky, from its public, account-free API: author, avatar,
 text, the first image and the date */
@implementation ICMBluesky

+ (nullable NSString *)_firstImageOfEmbed:(nullable NSDictionary *)embed
{
	if (embed == nil) {
		return nil;
	}

	NSArray *images = [embed arrayForKey:@"images"];

	if (images == nil) {
		images = [[embed dictionaryForKey:@"media"] arrayForKey:@"images"];
	}

	id firstImage = images.firstObject;

	if ([firstImage isKindOfClass:[NSDictionary class]]) {
		return [firstImage stringForKey:@"thumb"];
	}

	return [[embed dictionaryForKey:@"external"] stringForKey:@"thumb"];
}

+ (nullable NSString *)_formattedDate:(nullable NSString *)isoDate
{
	if (isoDate == nil) {
		return nil;
	}

	NSISO8601DateFormatter *parser = [NSISO8601DateFormatter new];

	parser.formatOptions = (NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds);

	NSDate *date = [parser dateFromString:isoDate];

	if (date == nil) {
		parser.formatOptions = NSISO8601DateFormatWithInternetDateTime;

		date = [parser dateFromString:isoDate];
	}

	if (date == nil) {
		return nil;
	}

	return [NSDateFormatter localizedStringFromDate:date dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle];
}

- (void)_performActionForPost:(NSString *)post ofActor:(NSString *)actor
{
	NSURLComponents *requestComponents = [NSURLComponents componentsWithString:@"https://public.api.bsky.app/xrpc/app.bsky.feed.getPostThread"];

	requestComponents.queryItems =
	@[
	  [NSURLQueryItem queryItemWithName:@"uri" value:[NSString stringWithFormat:@"at://%@/app.bsky.feed.post/%@", actor, post]],
	  [NSURLQueryItem queryItemWithName:@"depth" value:@"0"],
	  [NSURLQueryItem queryItemWithName:@"parentHeight" value:@"0"]
	];

	[ICLHelpers requestJSONDataFromURL:requestComponents.URL session:self.payload.session completionBlock:^(BOOL success, NSDictionary<NSString *, id> * _Nullable data) {
		NSDictionary *postData = [[data dictionaryForKey:@"thread"] dictionaryForKey:@"post"];

		NSDictionary *record = [postData dictionaryForKey:@"record"];

		NSDictionary *author = [postData dictionaryForKey:@"author"];

		if (record == nil || author == nil) {
			[self notifyUnableToPresentCard];

			return;
		}

		ICMPreviewCardContent *card = [ICMPreviewCardContent new];

		card.style = ICMPreviewCardStylePost;
		card.targetURL = self.payload.url;

		NSString *handle = [author stringForKey:@"handle"];

		card.authorName = ([author stringForKey:@"displayName"] ?: handle);

		if (handle) {
			card.authorHandle = [@"@" stringByAppendingString:handle];
		}

		NSString *avatar = [author stringForKey:@"avatar"];

		if (avatar) {
			card.avatarURL = [ICLHelpers URLWithString:avatar];
		}

		card.text = [record stringForKey:@"text"];

		NSString *image = [self.class _firstImageOfEmbed:[postData dictionaryForKey:@"embed"]];

		if (image) {
			card.imageURL = [ICLHelpers URLWithString:image];
		}

		card.details = @[@"Bluesky", ([self.class _formattedDate:[record stringForKey:@"createdAt"]] ?: @"")];

		[self performActionForCard:card];
	}];
}

#pragma mark -
#pragma mark Action Block

/* bsky.app/profile/<handle or DID>/post/<record key> */
+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSArray<NSString *> *components = [[url.path.percentEncodedURLPath trimCharacters:@"/"] componentsSeparatedByString:@"/"];

	if (components.count < 4 || [components[0] isEqualToString:@"profile"] == NO || [components[2] isEqualToString:@"post"] == NO) {
		return nil;
	}

	NSString *actor = components[1];
	NSString *post = components[3];

	if (actor.length == 0 || actor.length > 253 ||
		[actor onlyContainsCharactersFromCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:"]] == NO ||
		post.length == 0 || post.length > 20 ||
		[post onlyContainsCharactersFromCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz234567"]] == NO)
	{
		return nil;
	}

	return [^(ICLInlineContentModule *module) {
		[(ICMBluesky *)module _performActionForPost:post ofActor:actor];
	} copy];
}

+ (nullable NSArray<NSString *> *)domains
{
	return @[@"bsky.app", @"www.bsky.app"];
}

@end

NS_ASSUME_NONNULL_END
