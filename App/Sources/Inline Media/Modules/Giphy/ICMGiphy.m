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
#import "ICMGiphy.h"

NS_ASSUME_NONNULL_BEGIN

/* Giphy GIFs as clips that play like a GIF: Giphy serves every GIF as a much
 smaller MP4 too */
@implementation ICMGiphy

+ (nullable ICLInlineContentModuleActionBlock)actionBlockForURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSString *identifier = [self _identifierForURL:url];

	if (identifier == nil) {
		return nil;
	}

	return [super actionBlockForAddress:[NSString stringWithFormat:@"https://media.giphy.com/media/%@/giphy.mp4", identifier]];
}

/* giphy.com/gifs/<words>-<ID>, giphy.com/stickers/…, media.giphy.com/media/<ID>/…,
 i.giphy.com/<ID>.gif */
+ (nullable NSString *)_identifierForURL:(NSURL *)url
{
	NSString *host = url.host.lowercaseString;

	NSArray<NSString *> *components = [[url.path.percentEncodedURLPath trimCharacters:@"/"] componentsSeparatedByString:@"/"];

	NSString *identifier = nil;

	if ([host isEqualToString:@"giphy.com"] || [host isEqualToString:@"www.giphy.com"]) {
		if (components.count >= 2 && ([components[0] isEqualToString:@"gifs"] || [components[0] isEqualToString:@"stickers"])) {
			identifier = [components[1] componentsSeparatedByString:@"-"].lastObject;
		}
	} else if ([host isEqualToString:@"i.giphy.com"]) {
		identifier = components.firstObject.stringByDeletingPathExtension;
	} else if (components.count >= 2 && [components[0] isEqualToString:@"media"]) {
		identifier = components[1];

		/* media.giphy.com/media/v1.<token>/<ID>/giphy.gif */
		if ([identifier hasPrefix:@"v1."] && components.count >= 3) {
			identifier = components[2];
		}
	}

	if (identifier.length < 6 || identifier.length > 40 || identifier.isAlphabeticNumericOnly == NO) {
		return nil;
	}

	return identifier;
}

+ (nullable NSArray<NSString *> *)domains
{
	return @[@"giphy.com", @"www.giphy.com", @"i.giphy.com", @"media.giphy.com", @"media0.giphy.com", @"media1.giphy.com", @"media2.giphy.com", @"media3.giphy.com", @"media4.giphy.com"];
}

+ (BOOL)contentIsFile
{
	return YES;
}

@end

NS_ASSUME_NONNULL_END
