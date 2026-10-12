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

#import "IRCChannelPrivate.h"
#import "IRCChannelUser.h"
#import "TVCMemberListCellPrivate.h"
#import "TVCMemberListPrivate.h"
#import "TVCMemberListControllerPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface TVCMemberListController ()
@property (nonatomic, weak) TVCMemberList *memberList;
@property (nonatomic, weak, readwrite, nullable) IRCChannel *channel;
@property (nonatomic, weak, readwrite, nullable) IRCChannelMemberList *memberListShown;
@end

@implementation TVCMemberListController

- (instancetype)initWithMemberList:(TVCMemberList *)memberList
{
	NSParameterAssert(memberList != nil);

	if ((self = [super init])) {
		self.memberList = memberList;

		return self;
	}

	return nil;
}

- (void)dealloc
{
	[RZNotificationCenter() removeObserver:self];
}

/* Its list tells this controller about each change (rows inserted, removed,
 moved), so a selection stays with the same people */
- (void)showChannel:(nullable IRCChannel *)channel
{
	IRCChannel *channelShown = self.channel;

	if (channelShown) {
		[RZNotificationCenter() removeObserver:self name:IRCChannelMemberListWasCreatedNotification object:channelShown];
	}

	self.memberListShown.observer = nil;

	IRCChannelMemberList *memberList = channel.memberInfo;

	self.channel = channel;

	self.memberListShown = memberList;

	memberList.observer = self;

	if (channel) {
		[RZNotificationCenter() addObserver:self
								   selector:@selector(channelMemberListWasCreated:)
									   name:IRCChannelMemberListWasCreatedNotification
									 object:channel];
	}

	[self.memberList reloadData];
}

/* Joined while shown: the list didn't exist when the channel was selected */
- (void)channelMemberListWasCreated:(NSNotification *)notification
{
	XRPerformBlockSynchronouslyOnMainQueue(^{
		IRCChannel *channel = notification.object;

		if (channel != self.channel) {
			return;
		}

		[self.memberList assignToChannel:channel];
	});
}

#pragma mark -
#pragma mark Table View Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return self.memberListShown.numberOfMembers;
}

- (nullable id)tableView:(NSTableView *)tableView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	return [self.memberListShown memberAtIndex:row];
}

#pragma mark -
#pragma mark Table View Delegate

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	return [tableView makeViewWithIdentifier:@"GroupView" owner:self];
}

/* Reused: one was made for every row the table showed */
- (nullable NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
	TVCMemberListRowCell *rowView = [tableView makeViewWithIdentifier:@"MemberRow" owner:self];

	if (rowView == nil) {
		rowView = [[TVCMemberListRowCell alloc] initWithMemberList:self.memberList];

		rowView.identifier = @"MemberRow";
	}

	return rowView;
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
	[self.memberList refreshDrawingForRow:row];
}

#pragma mark -
#pragma mark Member List Changes

- (void)memberListInsertedRowAtIndex:(NSUInteger)index
{
	TVCMemberList *memberList = self.memberList;

	[memberList insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:index] withAnimation:NSTableViewAnimationEffectNone];

	[memberList memberListContentChanged];
}

- (void)memberListRemovedRowAtIndex:(NSUInteger)index
{
	TVCMemberList *memberList = self.memberList;

	[memberList removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:index] withAnimation:NSTableViewAnimationEffectNone];

	[memberList memberListContentChanged];
}

- (void)memberListMovedRowAtIndex:(NSUInteger)oldIndex toIndex:(NSUInteger)newIndex
{
	TVCMemberList *memberList = self.memberList;

	if (oldIndex != newIndex) {
		[memberList moveRowAtIndex:oldIndex toIndex:newIndex];

		[memberList memberListContentChanged];
	}

	/* A new member object: its cell shows the old one */
	[memberList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:newIndex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

/* Sorted again or cleared: the same people stay selected */
- (void)memberListReloaded
{
	TVCMemberList *memberList = self.memberList;

	NSMutableArray<IRCChannelUser *> *selectedMembers = [NSMutableArray array];

	[memberList.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
		IRCChannelUser *member = [memberList itemAtRow:index];

		if (member) {
			[selectedMembers addObject:member];
		}
	}];

	[memberList reloadData];

	NSMutableIndexSet *rowsToSelect = [NSMutableIndexSet indexSet];

	for (IRCChannelUser *member in selectedMembers) {
		NSInteger row = [memberList rowForItem:member];

		if (row >= 0) {
			[rowsToSelect addIndex:row];
		}
	}

	[memberList selectRowIndexes:rowsToSelect byExtendingSelection:NO];

	[memberList memberListContentChanged];
}

- (void)memberListWasDestroyed
{
	self.memberListShown = nil;

	TVCMemberList *memberList = self.memberList;

	[memberList reloadData];

	[memberList memberListContentChanged];
}

@end

NS_ASSUME_NONNULL_END
