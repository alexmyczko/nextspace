/*
   The viewer module protocol.

   Copyright (C) 2005 Saso Kiselkov

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

@class NSView, NSString, NSArray;

@class FileViewer;

#import <Foundation/NSObject.h>

@protocol Viewer <NSObject>

+ (NSString *)viewerType;
 // viewers without a shortcut should return @"", not `nil'
+ (NSString *)viewerShortcut;

- (NSView *)view;
- (NSView *)keyView;

- (void)setOwner:(FileViewer *)owner;
- (void)setRootPath:(NSString *)rootPath;
- (NSString *)fullPath;

- (CGFloat)columnWidth;
- (void)setColumnWidth:(CGFloat)width;
- (NSUInteger)columnCount;
- (void)setColumnCount:(NSUInteger)num;
- (void)setNumberOfEmptyColumns:(NSInteger)num;
- (NSInteger)numberOfEmptyColumns;

//-----------------------------------------------------------------------------
// Actions
//-----------------------------------------------------------------------------
- (void)displayPath:(NSString *)dirPath
	  selection:(NSArray *)filenames;

- (void)reloadPathWithSelection:(NSString *)selection; // Reload contents of selected directory
- (void)reloadPath:(NSString *)reloadPath;

- (void)scrollToRange:(NSRange)range;

- (BOOL)becomeFirstResponder;

//-----------------------------------------------------------------------------
// Events
//-----------------------------------------------------------------------------
- (void)currentSelectionRenamedTo:(NSString *)newName;

@end
