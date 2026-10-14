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

NS_ASSUME_NONNULL_BEGIN

/* One URL session for inline media requests (the media assessor, the
 JSON lookups, and later the link cards), and one more for each proxy a
 server uses: a server's previews go through its proxy. Ephemeral: no cookies, no
 cache, no credentials. Requests time out after 20 seconds, at most 5
 redirects are followed, and every address, including each redirect, is
 refused if it points at the local network (R1.7): loopback, private,
 link-local, unique local, multicast, .local and single-label names, and
 host names that resolve to any of these. Callbacks and completion blocks
 run on the main thread. Clicking a refused link still opens it. */
@class IRCClient;

/* How a session's host names are checked. Through a proxy the proxy looks
 names up, so Textual must not (that would leak them past the proxy, and
 .onion names only resolve in Tor): only literal addresses and local-looking
 names are refused there. */
typedef NS_ENUM(NSUInteger, ICLURLSessionResolution) {
	ICLURLSessionResolutionLocal = 0, // no proxy: host names are looked up and refused if any address is local
	ICLURLSessionResolutionProxy, // SOCKS or HTTP proxy: no lookup; .onion refused
	ICLURLSessionResolutionTor // Tor: no lookup; .onion allowed
};

@interface ICLURLSession : NSObject
@property (readonly, class) NSURLSession *sharedSession;

/* The session for a server's previews: through its proxy when it has one */
+ (NSURLSession *)sessionForClient:(nullable IRCClient *)client;

/* The same proxy and rules for media the chat view streams (video, audio):
 requests still time out after 20 seconds without data, but the whole
 download may take as long as the media plays */
+ (NSURLSession *)mediaSessionForSession:(NSURLSession *)session;

+ (ICLURLSessionResolution)resolutionForSession:(NSURLSession *)session;

/* Every session, for cancelling their requests */
@property (readonly, class) NSArray<NSURLSession *> *allSessions;

/* YES for an HTTPS URL whose host is not a local address or name (App
 Transport Security refuses plain HTTP). Does not resolve the host name. */
+ (BOOL)URLIsAllowed:(NSURL *)url;
+ (BOOL)URLIsAllowed:(NSURL *)url withResolution:(ICLURLSessionResolution)resolution; // .onion only for Tor

/* +URLIsAllowed: and, for host names without a proxy, a lookup of their addresses */
+ (void)checkURL:(NSURL *)url completionBlock:(void (^)(BOOL allowed))completionBlock;
+ (void)checkURL:(NSURL *)url session:(NSURLSession *)session completionBlock:(void (^)(BOOL allowed))completionBlock;

/* GET with a response size limit. data is nil when the address is refused,
 the request fails, the status is not 200 or the body exceeds maximumLength. */
+ (void)requestDataFromURL:(NSURL *)url session:(NSURLSession *)session maximumLength:(NSUInteger)maximumLength completionBlock:(void (^)(NSData * _Nullable data))completionBlock;
@end

NS_ASSUME_NONNULL_END
