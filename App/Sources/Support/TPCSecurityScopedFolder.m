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

#import "TPCPreferencesUserDefaults.h"
#import "TPCSecurityScopedFolderPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TPCSecurityScopedFolder ()
@property (nonatomic, copy, readwrite) NSString *bookmarkKey;
@property (nonatomic, copy, readwrite, nullable) NSURL *URL;
@property (nonatomic, assign) BOOL isAccessed;
@end

@implementation TPCSecurityScopedFolder

- (instancetype)initWithBookmarkKey:(NSString *)bookmarkKey
{
	NSParameterAssert(bookmarkKey != nil);

	if ((self = [super init])) {
		self.bookmarkKey = bookmarkKey;

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[self stopAccessing];
}

- (BOOL)startAccessing
{
	if (self.URL != nil) {
		return YES;
	}

	NSData *bookmark = [RZUserDefaults() dataForKey:self.bookmarkKey];

	if (bookmark == nil) {
		return YES;
	}

	BOOL bookmarkIsStale = NO;

	NSError *resolveError = nil;

	NSURL *URL =
	[NSURL URLByResolvingBookmarkData:bookmark
							  options:NSURLBookmarkResolutionWithSecurityScope
						relativeToURL:nil
				  bookmarkDataIsStale:&bookmarkIsStale
								error:&resolveError];

	if (URL == nil) {
		LogToConsoleError("Error resolving bookmark for '%{public}@': %{public}@",
			self.bookmarkKey, resolveError.localizedDescription);

		return NO;
	}

	self.URL = URL;

	self.isAccessed = [URL startAccessingSecurityScopedResource];

	if (self.isAccessed == NO) {
		LogToConsoleError("Failed to access bookmark for '%{public}@'", self.bookmarkKey);

		return YES;
	}

	/* "On return, if YES, the bookmark data is stale. Your app should create a
	 new bookmark using the returned URL and use it in place of any stored
	 copies of the existing bookmark." It can only be made while accessed. */
	if (bookmarkIsStale) {
		NSData *newBookmark = [self.class bookmarkForURL:URL];

		if (newBookmark == nil) {
			return NO;
		}

		[RZUserDefaults() setObject:newBookmark forKey:self.bookmarkKey];
	}

	return YES;
}

- (void)stopAccessing
{
	if (self.isAccessed) {
		[self.URL stopAccessingSecurityScopedResource];

		self.isAccessed = NO;
	}

	self.URL = nil;
}

- (BOOL)setBookmark:(nullable NSData *)bookmark
{
	[self stopAccessing];

	[RZUserDefaults() setObject:bookmark forKey:self.bookmarkKey];

	return [self startAccessing];
}

+ (nullable NSData *)bookmarkForURL:(NSURL *)URL
{
	NSParameterAssert(URL != nil);

	NSError *bookmarkError = nil;

	NSData *bookmark = [URL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
					 includingResourceValuesForKeys:nil
									  relativeToURL:nil
											  error:&bookmarkError];

	if (bookmark == nil) {
		LogToConsoleError("Error creating bookmark for URL ('%{public}@'): %{public}@",
			URL.path, bookmarkError.localizedDescription);
	}

	return bookmark;
}

@end

NS_ASSUME_NONNULL_END
