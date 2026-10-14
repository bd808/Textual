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

#import "TPCPreferencesLocalPrivate.h"
#import "TPCPreferencesReloadPrivate.h"
#import "TPCPreferencesUserDefaults.h"
#import "ICLInlineContentLoaderPrivate.h"
#import "ICPCoreMediaPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TPCPreferencesTests : XCTestCase
@end

@implementation TPCPreferencesTests

/* Changing a setting reloads what depends on it, and only that: the two scrollback
 limits are separate (the visible one never applied, R7.9) */
- (void)testReloadActionForKeys
{
	TPCPreferencesReloadAction visible = [TPCPreferences reloadActionForKeys:@[@"ScrollbackMaximumVisibleLineCount"]];

	XCTAssertTrue((visible & TPCPreferencesReloadActionScrollbackVisibleLimit) == TPCPreferencesReloadActionScrollbackVisibleLimit);
	XCTAssertFalse((visible & TPCPreferencesReloadActionScrollbackSaveLimit) == TPCPreferencesReloadActionScrollbackSaveLimit);

	TPCPreferencesReloadAction saved = [TPCPreferences reloadActionForKeys:@[@"ScrollbackMaximumSavedLineCount"]];

	XCTAssertTrue((saved & TPCPreferencesReloadActionScrollbackSaveLimit) == TPCPreferencesReloadActionScrollbackSaveLimit);
	XCTAssertFalse((saved & TPCPreferencesReloadActionScrollbackVisibleLimit) == TPCPreferencesReloadActionScrollbackVisibleLimit);

	TPCPreferencesReloadAction style = [TPCPreferences reloadActionForKeys:@[@"Theme -> Timestamp Format"]];

	XCTAssertTrue((style & TPCPreferencesReloadActionStyle) == TPCPreferencesReloadActionStyle);

	/* Every change ends in the general "preferences changed" pass */
	XCTAssertEqual([TPCPreferences reloadActionForKeys:@[]], TPCPreferencesReloadActionPreferencesChanged);
}

/* The "Join, Part, Quit" checkbox carries over once as Show or Hide, then its key
 is gone; without it the default (Collapse) stays */
- (void)testGeneralEventMigration
{
	NSString *checkboxKey = TPCPreferencesGeneralEventCheckboxDefaultsKey;
	NSString *displayKey = TPCPreferencesGeneralEventDisplayDefaultsKey;

	id savedDisplay = [RZUserDefaults() objectForKey:displayKey];

	[RZUserDefaults() removeObjectForKey:displayKey];

	[RZUserDefaults() setBool:NO forKey:checkboxKey];

	[TPCPreferences migrateGeneralEventPreference];

	XCTAssertEqual([TPCPreferences generalEventDisplay], TXGeneralEventDisplayHide);
	XCTAssertFalse([TPCPreferences showJoinLeave]);
	XCTAssertNil([RZUserDefaults() objectForKey:checkboxKey]);

	[RZUserDefaults() setBool:YES forKey:checkboxKey];

	[TPCPreferences migrateGeneralEventPreference];

	XCTAssertEqual([TPCPreferences generalEventDisplay], TXGeneralEventDisplayShow);

	[RZUserDefaults() removeObjectForKey:displayKey];

	[TPCPreferences migrateGeneralEventPreference];

	XCTAssertEqual([TPCPreferences generalEventDisplay], TXGeneralEventDisplayCollapse);

	/* Textual 7 showed them when the checkbox was never changed (no key) */
	XCTAssertEqual([TPCPreferences generalEventDisplayForCheckboxValue:nil], TXGeneralEventDisplayShow);

	if (savedDisplay) {
		[RZUserDefaults() setObject:savedDisplay forKey:displayKey];
	}
}

/* "Only inline images and videos" (D-E2.12): service cards and web page cards
 off, files and clip services stay; every Textual 7 limit is gone afterwards */
- (void)testInlineMediaLimitsMigration
{
	NSArray<NSString *> *limitKeys = @[@"InlineMediaLimitToBasics", @"InlineMediaLimitBasicsToFiles", @"InlineMediaLimitInsecureContent", @"InlineMediaLimitNaughtyContent", @"InlineMediaLimitUnsafeContent", @"InlineMediaCheckEverything"];

	NSArray<NSString *> *savedServices = [TPCPreferences inlineMediaDisabledServices];

	BOOL savedWebPageCards = [TPCPreferences inlineMediaWebPageCards];

	TPCPreferences.inlineMediaDisabledServices = @[];

	[TPCPreferences setInlineMediaWebPageCards:YES];

	for (NSString *limitKey in limitKeys) {
		[RZUserDefaults() setBool:YES forKey:limitKey];
	}

	[TPCPreferences migrateInlineMediaLimits];

	XCTAssertFalse([TPCPreferences inlineMediaWebPageCards]);
	XCTAssertFalse([TPCPreferences inlineMediaServiceIsEnabled:@"YouTube"]);
	XCTAssertFalse([TPCPreferences inlineMediaServiceIsEnabled:@"X"]);
	XCTAssertFalse([TPCPreferences inlineMediaServiceIsEnabled:@"Bandcamp"]);
	XCTAssertTrue([TPCPreferences inlineMediaServiceIsEnabled:@"Giphy"]);
	XCTAssertTrue([TPCPreferences inlineMediaServiceIsEnabled:@"xkcd"]);
	XCTAssertTrue([[ICPCoreMedia serviceNames] containsObject:@"Giphy"]);

	for (NSString *limitKey in limitKeys) {
		XCTAssertNil([RZUserDefaults() objectForKey:limitKey], @"%@", limitKey);
	}

	/* Without the limit, nothing changes */
	TPCPreferences.inlineMediaDisabledServices = @[];

	[TPCPreferences setInlineMediaWebPageCards:YES];

	[RZUserDefaults() setBool:NO forKey:@"InlineMediaLimitToBasics"];

	[TPCPreferences migrateInlineMediaLimits];

	XCTAssertTrue([TPCPreferences inlineMediaWebPageCards]);
	XCTAssertEqualObjects([TPCPreferences inlineMediaDisabledServices], @[]);

	TPCPreferences.inlineMediaDisabledServices = savedServices;

	[TPCPreferences setInlineMediaWebPageCards:savedWebPageCards];
}

/* Preferences → Inline Media → Rules: a site covers its subdomains, not
 lookalikes; typed or pasted sites become plain domains */
- (void)testInlineMediaDomainRules
{
	NSArray<NSString *> *domains = @[@"example.com", @"cdn.other.org"];

	TXInlineMediaDomainRuleMode except = TXInlineMediaDomainRuleModeExcept;
	TXInlineMediaDomainRuleMode only = TXInlineMediaDomainRuleModeOnly;

	XCTAssertFalse([ICLInlineContentLoader host:@"example.com" isPreviewedWithDomains:domains mode:except]);
	XCTAssertFalse([ICLInlineContentLoader host:@"www.EXAMPLE.com" isPreviewedWithDomains:domains mode:except]);
	XCTAssertTrue([ICLInlineContentLoader host:@"badexample.com" isPreviewedWithDomains:domains mode:except]);
	XCTAssertTrue([ICLInlineContentLoader host:@"other.org" isPreviewedWithDomains:domains mode:except]);
	XCTAssertTrue([ICLInlineContentLoader host:@"anything.net" isPreviewedWithDomains:@[] mode:except]);

	XCTAssertTrue([ICLInlineContentLoader host:@"img.cdn.other.org" isPreviewedWithDomains:domains mode:only]);
	XCTAssertFalse([ICLInlineContentLoader host:@"other.org" isPreviewedWithDomains:domains mode:only]);
	XCTAssertFalse([ICLInlineContentLoader host:@"anything.net" isPreviewedWithDomains:@[] mode:only]);

	XCTAssertEqualObjects([TPCPreferences normalizedInlineMediaDomain:@" https://www.Example.com/page?x=1 "], @"www.example.com");
	XCTAssertEqualObjects([TPCPreferences normalizedInlineMediaDomain:@"*.example.com"], @"example.com");
	XCTAssertEqualObjects([TPCPreferences normalizedInlineMediaDomain:@"example.com/path"], @"example.com");
	XCTAssertNil([TPCPreferences normalizedInlineMediaDomain:@"localhost"]);
	XCTAssertNil([TPCPreferences normalizedInlineMediaDomain:@"user@example.com"]);
	XCTAssertNil([TPCPreferences normalizedInlineMediaDomain:@""]);
}

/* Textual 7's Caffeine extension setting carries over once, then its key is gone */
- (void)testCaffeineMigration
{
	NSString *extensionKey = @"Private Extension Store -> Caffeine Extension -> Prevent Sleep";
	NSString *preferenceKey = @"PreventSleepWhileConnected";

	id savedPreference = [RZUserDefaults() objectForKey:preferenceKey];

	[RZUserDefaults() setBool:NO forKey:preferenceKey];
	[RZUserDefaults() setBool:YES forKey:extensionKey];

	[TPCPreferences migrateCaffeinePreference];

	XCTAssertTrue([RZUserDefaults() boolForKey:preferenceKey]);
	XCTAssertNil([RZUserDefaults() objectForKey:extensionKey]);

	/* Without the extension's key nothing changes */
	[RZUserDefaults() setBool:NO forKey:preferenceKey];

	[TPCPreferences migrateCaffeinePreference];

	XCTAssertFalse([RZUserDefaults() boolForKey:preferenceKey]);

	if (savedPreference) {
		[RZUserDefaults() setObject:savedPreference forKey:preferenceKey];
	} else {
		[RZUserDefaults() removeObjectForKey:preferenceKey];
	}
}

@end

NS_ASSUME_NONNULL_END
