/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\__|\__,_|\__,_|_|
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

#import <XCTest/XCTest.h>

#import "ICLHelpers.h"
#import "ICMPreviewCard.h"
#import "ICMTweet.h"

NS_ASSUME_NONNULL_BEGIN

@interface ICMPreviewCardTests : XCTestCase
@end

@implementation ICMPreviewCardTests

/* X's oEmbed blockquote, as X sends it: the post's text (links and line breaks
 inside), then the author and a dated link */
- (void)testPostTextAndDateFromEmbedHTML
{
	NSString *html = @"<blockquote class=\"twitter-tweet\"><p lang=\"en\" dir=\"ltr\">Fish &amp; chips<br>at <a href=\"https://t.co/x\">t.co/x</a> &#8212; &quot;yes&quot; &#x1F600;</p>&mdash; Jack (@jack) <a href=\"https://x.com/jack/status/20?ref_src=twsrc%5Etfw\">March 21, 2006</a></blockquote>\n";

	NSDictionary<NSString *, NSString *> *post = [ICMTweet postFromEmbedHTML:html];

	XCTAssertEqualObjects(post[@"text"], @"Fish & chips\nat t.co/x \u2014 \"yes\" \U0001F600");
	XCTAssertEqualObjects(post[@"date"], @"March 21, 2006");

	/* Not what X sends: nothing, rather than markup */
	XCTAssertNil([ICMTweet postFromEmbedHTML:@"<div>no paragraph</div>"]);
	XCTAssertNil([ICMTweet postFromEmbedHTML:@"<p>never closed"]);

	/* Unknown or broken entities stay as they were */
	XCTAssertEqualObjects([ICLHelpers plainTextFromHTMLFragment:@"a &bogus; b &#xD800; c & d"], @"a &bogus; b &#xD800; c & d");
}

/* A page's title and Open Graph values from its head, however the tags are
 written; nothing after </head> counts */
- (void)testPageMetadataFromHead
{
	NSString *html = @"<html><head><TITLE>Plain &amp; title</TITLE>"
					  "<meta property=\"og:title\" content=\"box, by GGG &quot;Blanstein&quot;\">"
					  "<meta content='https://f4.bcbits.com/img/a1_5.jpg' property='og:image'/>"
					  "<meta property=\"og:image\" content=\"https://example.com/second.jpg\">"
					  "<meta name=\"twitter:card\" content=\"summary\">"
					  "<meta name=\"description\" content=\"not Open Graph\">"
					  "<meta xproperty=\"og:site_name\" content=\"not a property attribute\">"
					  "</head><body><meta property=\"og:description\" content=\"in the body\"></body></html>";

	NSDictionary<NSString *, NSString *> *metadata = [ICLHelpers metadataInHTML:html];

	XCTAssertEqualObjects(metadata[@"title"], @"Plain & title");
	XCTAssertEqualObjects(metadata[@"og:title"], @"box, by GGG \"Blanstein\"");
	XCTAssertEqualObjects(metadata[@"og:image"], @"https://f4.bcbits.com/img/a1_5.jpg");
	XCTAssertEqualObjects(metadata[@"twitter:card"], @"summary");
	XCTAssertNil(metadata[@"description"]);
	XCTAssertNil(metadata[@"og:site_name"]);
	XCTAssertNil(metadata[@"og:description"]);
}

- (void)testDurations
{
	XCTAssertEqualObjects([ICMPreviewCard formattedDuration:62], @"1:02");
	XCTAssertEqualObjects([ICMPreviewCard formattedDuration:3723], @"1:02:03");
	XCTAssertEqualObjects([ICMPreviewCard formattedDuration:9.6], @"0:10");
}

@end

NS_ASSUME_NONNULL_END
