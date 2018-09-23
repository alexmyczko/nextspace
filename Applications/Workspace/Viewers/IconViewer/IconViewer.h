/*
   The Icon viewer.

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

#import <AppKit/AppKit.h>

#import <Viewers/FileViewer.h>
#import <Viewers/Viewer.h>

@class NXIconView, NXIcon, NXIconLabel;

@interface WMIconView : NXIconView
{
  BOOL isDrawOpenAnimation;
}
- (void)drawOpenAnimation;
- (BOOL)isAnimating;
@end

@interface ViewerItemsLoader : NSOperation
{
  WMIconView     *iconView;
  NSString       *directoryPath;
  NSMutableArray *directoryContents;
  NSArray        *selectedFiles;
  BOOL           isUpdate;
  BOOL           isAnimate;
}

- (id)initWithIconView:(NXIconView *)view
                  path:(NSString *)dirPath
              contents:(NSArray *)dirContents
             selection:(NSArray *)filenames
                update:(BOOL)toUpdate
               animate:(BOOL)isDrawAnimation;

@end

@interface IconViewer : NSObject <Viewer>
{
  FileViewer   *_owner;

  NSScrollView *view;
  WMIconView   *iconView;

  NSString     *rootPath;
  NSString     *currentPath;
  NSArray      *selection;
  BOOL         updateOnDisplay;
  BOOL         doAnimation;

  // Items loader
  NSOperationQueue	*operationQ;
  ViewerItemsLoader	*itemsLoader;
  
  // Dragging
  id         _dragSource;
  PathIcon   *_dragIcon;
  unsigned   _dragMask;
}

- (void)open:(id)sender;

@end
