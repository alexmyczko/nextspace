/*
   The FileOperation tool's deletion functions.

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

#import <Foundation/Foundation.h>

void DeleteOperation(NSString *dir, NSArray *files);

@interface Deleter : NSObject

- (BOOL) fileManager: (NSFileManager*)fileManager
  shouldProceedAfterError: (NSDictionary*)errorDictionary;

// - (void) fileManager: (NSFileManager*)fileManager
//      willProcessPath: (NSString*)path;

@end
