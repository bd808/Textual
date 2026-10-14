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

#import "ICLURLSessionPrivate.h"
#import "ICLMediaSchemeHandlerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

/* A server inside the test: path → status, headers and body. Redirects go to
 the Location header. The last Range header received is kept. */
@interface ICLMediaFetchTestsProtocol : NSURLProtocol
@end

static NSDictionary<NSString *, NSDictionary *> *_stubResponses = nil;
static NSString * _Nullable _lastRangeHeader = nil;

@implementation ICLMediaFetchTestsProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
	return request;
}

- (void)startLoading
{
	NSURLRequest *request = self.request;

	_lastRangeHeader = [request valueForHTTPHeaderField:@"Range"];

	NSDictionary *stub = _stubResponses[request.URL.path];

	if (stub == nil) {
		[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil]];

		return;
	}

	NSInteger statusCode = [stub[@"status"] integerValue];

	NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:stub[@"headers"]];

	NSString *location = stub[@"headers"][@"Location"];

	if (location) {
		NSURLRequest *redirect = [NSURLRequest requestWithURL:[NSURL URLWithString:location]];

		[self.client URLProtocol:self wasRedirectedToRequest:redirect redirectResponse:response];

		[self.client URLProtocolDidFinishLoading:self];

		return;
	}

	[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];

	NSData *body = stub[@"body"];

	if (body) {
		[self.client URLProtocol:self didLoadData:body];
	}

	[self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading
{
}

@end

#pragma mark -

@interface ICLMediaFetchTests : XCTestCase
@end

@implementation ICLMediaFetchTests

/* A preview session (ICLURLSession's redirect rules) on the test server.
 Public literal addresses: no name lookup in the test. */
- (NSURLSession *)session
{
	NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];

	configuration.protocolClasses = @[[ICLMediaFetchTestsProtocol class]];

	NSURLSession *baseSession = [NSURLSession sessionWithConfiguration:configuration];

	return [ICLURLSession mediaSessionForSession:baseSession];
}

- (nullable NSError *)fetchPath:(NSString *)path type:(ICLMediaType)type maximumLength:(unsigned long long)maximumLength range:(nullable NSString *)range statusCode:(NSInteger *)statusCode headers:(NSDictionary * _Nullable * _Nullable)headers length:(NSUInteger *)length
{
	NSURL *url = [NSURL URLWithString:[@"https://8.8.8.8" stringByAppendingString:path]];

	ICLMediaFetch *fetch = [[ICLMediaFetch alloc] initWithURL:url session:self.session type:type maximumLength:maximumLength rangeHeader:range];

	XCTestExpectation *finished = [self expectationWithDescription:path];

	__block NSError *fetchError = nil;
	__block NSUInteger receivedLength = 0;
	__block NSInteger receivedStatusCode = 0;
	__block NSDictionary *receivedHeaders = nil;

	fetch.responseBlock = ^(NSInteger responseStatusCode, NSDictionary<NSString *, NSString *> *headerFields) {
		receivedStatusCode = responseStatusCode;
		receivedHeaders = headerFields;
	};

	fetch.dataBlock = ^(NSData *data) {
		receivedLength += data.length;
	};

	fetch.completionBlock = ^(NSError * _Nullable error) {
		fetchError = error;

		[finished fulfill];
	};

	[fetch start];

	[self waitForExpectations:@[finished] timeout:10];

	*length = receivedLength;

	*statusCode = receivedStatusCode;

	if (headers) {
		*headers = receivedHeaders;
	}

	return fetchError;
}

- (void)tearDown
{
	_stubResponses = nil;
	_lastRangeHeader = nil;

	[super tearDown];
}

/* Only the content types of the kind expected reach the chat view */
- (void)testUnexpectedContentTypeIsRefused
{
	_stubResponses = @{
		@"/page.png" : @{@"status" : @200, @"headers" : @{@"Content-Type" : @"text/html", @"Content-Length" : @"5"}, @"body" : [@"<html" dataUsingEncoding:NSUTF8StringEncoding]},
		@"/image.png" : @{@"status" : @200, @"headers" : @{@"Content-Type" : @"image/png", @"Content-Length" : @"4"}, @"body" : [@"PNG!" dataUsingEncoding:NSUTF8StringEncoding]}
	};

	NSInteger statusCode = 0;
	NSUInteger length = 0;

	NSError *error = [self fetchPath:@"/page.png" type:ICLMediaTypeImage maximumLength:1000 range:nil statusCode:&statusCode headers:NULL length:&length];

	XCTAssertEqual(error.code, ICLMediaFetchErrorCodeUnexpectedType);
	XCTAssertEqual(length, 0);

	error = [self fetchPath:@"/image.png" type:ICLMediaTypeImage maximumLength:1000 range:nil statusCode:&statusCode headers:NULL length:&length];

	XCTAssertNil(error);
	XCTAssertEqual(statusCode, 200);
	XCTAssertEqual(length, 4);
}

/* The size limit holds by the headers and by the body (headers can lie) */
- (void)testSizeLimitIsEnforced
{
	NSData *body = [NSMutableData dataWithLength:2000];

	_stubResponses = @{
		@"/large.png" : @{@"status" : @200, @"headers" : @{@"Content-Type" : @"image/png", @"Content-Length" : @"2000"}, @"body" : body},
		@"/lying.png" : @{@"status" : @200, @"headers" : @{@"Content-Type" : @"image/png"}, @"body" : body}
	};

	NSInteger statusCode = 0;
	NSUInteger length = 0;

	XCTAssertEqual([self fetchPath:@"/large.png" type:ICLMediaTypeImage maximumLength:1000 range:nil statusCode:&statusCode headers:NULL length:&length].code, ICLMediaFetchErrorCodeTooLarge);
	XCTAssertEqual([self fetchPath:@"/lying.png" type:ICLMediaTypeImage maximumLength:1000 range:nil statusCode:&statusCode headers:NULL length:&length].code, ICLMediaFetchErrorCodeTooLarge);

	/* Video you play has no limit */
	_stubResponses = @{@"/video.mp4" : @{@"status" : @200, @"headers" : @{@"Content-Type" : @"video/mp4", @"Content-Length" : @"2000"}, @"body" : body}};

	XCTAssertNil([self fetchPath:@"/video.mp4" type:ICLMediaTypeVideo maximumLength:0 range:nil statusCode:&statusCode headers:NULL length:&length]);
	XCTAssertEqual(length, 2000);
}

/* Seeking in a video: WebKit's Range request reaches the server, and the
 partial response comes back with its range */
- (void)testRangeRequestsPassThrough
{
	_stubResponses = @{
		@"/video.mp4" : @{@"status" : @206, @"headers" : @{@"Content-Type" : @"video/mp4", @"Content-Length" : @"100", @"Content-Range" : @"bytes 100-199/5000", @"Accept-Ranges" : @"bytes"}, @"body" : [NSMutableData dataWithLength:100]}
	};

	NSInteger statusCode = 0;
	NSDictionary *headers = nil;
	NSUInteger length = 0;

	NSError *error = [self fetchPath:@"/video.mp4" type:ICLMediaTypeVideo maximumLength:0 range:@"bytes=100-199" statusCode:&statusCode headers:&headers length:&length];

	XCTAssertNil(error);
	XCTAssertEqualObjects(_lastRangeHeader, @"bytes=100-199");
	XCTAssertEqual(statusCode, 206);
	XCTAssertEqualObjects(headers[@"Content-Range"], @"bytes 100-199/5000");
	XCTAssertEqualObjects(headers[@"Accept-Ranges"], @"bytes");
	XCTAssertEqual(length, 100);

	/* A partial response nobody asked for is refused */
	XCTAssertEqual([self fetchPath:@"/video.mp4" type:ICLMediaTypeVideo maximumLength:0 range:nil statusCode:&statusCode headers:NULL length:&length].code, ICLMediaFetchErrorCodeUnexpectedResponse);
}

/* A redirect into the local network is refused like the address itself (R1.7) */
- (void)testRedirectToLocalAddressIsRefused
{
	_stubResponses = @{
		@"/redirect.png" : @{@"status" : @302, @"headers" : @{@"Location" : @"https://192.168.1.1/admin.png"}},
		@"/admin.png" : @{@"status" : @200, @"headers" : @{@"Content-Type" : @"image/png", @"Content-Length" : @"4"}, @"body" : [NSMutableData dataWithLength:4]}
	};

	NSInteger statusCode = 0;
	NSUInteger length = 0;

	NSError *error = [self fetchPath:@"/redirect.png" type:ICLMediaTypeImage maximumLength:1000 range:nil statusCode:&statusCode headers:NULL length:&length];

	XCTAssertNotNil(error);
	XCTAssertEqual(length, 0);
}

@end

NS_ASSUME_NONNULL_END
