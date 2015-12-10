/*
 * NXScrren.m
 *
 * Provides integration with XRandR subsystem.
 * Manage display layouts.
 *
 * Copyright 2015, Serg Stoyan
 * All right reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
// screen:
// typedef struct _XRRScreenResources {
//   Time        timestamp;
//   Time        configTimestamp;
//   int         ncrtc;
//   RRCrtc      *crtcs;
//   int         noutput;
//   RROutput    *outputs;
//   int         nmode;
//   XRRModeInfo *modes;
// } XRRScreenResources;
*/

#import "NXDisplay.h"
#import "NXScreen.h"

@interface NXScreen (Private)
- (NSSize)_sizeInPixels;
- (NSSize)_sizeInPixelsForLayout:(NSArray *)layout;
- (NSSize)_sizeInMilimeters;
- (void)_refreshDisplaysInfo;
@end

@implementation NXScreen (Private)
// Calculate screen size in pixels using current displays information
- (NSSize)_sizeInPixels
{
  CGFloat width = 0.0, height = 0.0, w = 0.0, h = 0.0;
  NSRect  dFrame;
  
  for (NXDisplay *display in systemDisplays)
    {
      if ([display isConnected] && [display isActive])
        {
          dFrame = [display frame];
          
          w = dFrame.origin.x + dFrame.size.width;
          if (w > width) width = w;

          h = dFrame.origin.y + dFrame.size.height;
          if (h > height) height = h;
        }
    }

  return NSMakeSize(width, height);
}

// Calculate screen size in pixels using displays information contained
// in 'layout'.
// Doesn't change 'sizeInPixels' ivar.
- (NSSize)_sizeInPixelsForLayout:(NSArray *)layout
{
  CGFloat width = 0.0, height = 0.0, w = 0.0, h = 0.0;
  NSSize       size;
  NSPoint      origin;
  NSDictionary *resolution;
  
  for (NSDictionary *display in layout)
    {
      if ([[display objectForKey:@"Active"] isEqualToString:@"NO"])
        continue;
      
      origin = NSPointFromString([display objectForKey:@"Origin"]);
      resolution = [display objectForKey:@"Resolution"];
      size = NSSizeFromString([resolution objectForKey:@"Dimensions"]);
          
      w = origin.x + size.width;
      if (w > width) width = w;

      h = origin.y + size.height;
      if (h > height) height = h;
    }

  return NSMakeSize(width, height);
}

// Physical size of screen based on physical sizes of monitors.
// For VM (size of all monitors is 0x0 mm) returns 200x200.
// Doesn't change 'sizeInMilimetres' ivar.
- (NSSize)_sizeInMilimeters
{
  CGFloat      width = 0.0, height = 0.0;
  NSSize       dPSize, pixSize;
  NSDictionary *mode;
  
  for (NXDisplay *display in systemDisplays)
    {
      if ([display isConnected] && [display isActive])
        {
          dPSize = [display physicalSize];
          
          if (dPSize.width > width)
            width = dPSize.width;
          else if (dPSize.width == 0)
            width = 200; // perhaps it's VM, this number will be ignored
          
          if (dPSize.height > height)
            height = dPSize.height;
          else if (dPSize.height == 0)
            height = 200; // perhaps it's VM, this number will be ignored
        }
    }
  
  return NSMakeSize(width, height);
}

// Update display information local cache.
- (void)_refreshDisplaysInfo
{
  NXDisplay *display;

  if (systemDisplays) [systemDisplays release];
  systemDisplays = [[NSMutableArray alloc] init];

  if (screen_resources == NULL)
    {
      screen_resources = XRRGetScreenResources(xDisplay, xRootWindow);
    }

  for (int i=0; i < screen_resources->noutput; i++)
    {
      display = [[NXDisplay alloc]
	initWithOutputInfo:screen_resources->outputs[i]
		    screen:self
		  xDisplay:xDisplay];
      
      if (XRRGetOutputPrimary(xDisplay, xRootWindow) ==
          screen_resources->outputs[i])
        {
          mainDisplay = display;
        }
      
      [systemDisplays addObject:display];
      [display release];      
    }
  
  // Update screen dimensions
  sizeInPixels = [self _sizeInPixels];
  sizeInMilimeters = [self _sizeInMilimeters];
}

@end

@implementation NXScreen
static id systemScreen = nil;

+ (id)sharedScreen
{
  if (systemScreen == nil)
    {
      self = systemScreen = [NXScreen new];
    }

  return systemScreen;
}

- (id)init
{
  self = [super init];

  xDisplay = XOpenDisplay(getenv("DISPLAY"));
  if (!xDisplay)
    {
      NSLog(@"Can't open Xorg display.");
      return nil;
    }
  
  xRootWindow = RootWindow(xDisplay, DefaultScreen(xDisplay));
  screen_resources = NULL;

  [self _refreshDisplaysInfo];

  // Initially we set primary display to first active
  if ([self mainDisplay] == nil)
    {
      NSLog(@"NXScreen: main display not found, setting first active as main...");
      for (NXDisplay *display in systemDisplays)
        {
          if ([display isActive])
            {
              [display setMain:YES];
              break;
            }
        }
    }

  return self;
}

- (void)dealloc
{
  XRRFreeScreenResources(screen_resources);
  
  XCloseDisplay(xDisplay);

  [super dealloc];
}

- (XRRScreenResources *)randrScreenResources
{
  XRRFreeScreenResources(screen_resources);
  screen_resources = XRRGetScreenResources(xDisplay, xRootWindow);
  return screen_resources;
}

- (RRCrtc)randrFindFreeCRTC
{
  RRCrtc      crtc;
  XRRCrtcInfo *info;

  for (int i=0; i<screen_resources->ncrtc; i++)
    {
      crtc = screen_resources->crtcs[i];
      info = XRRGetCrtcInfo(xDisplay, screen_resources, crtc);
      // fprintf(stderr, "CRTC '%lu' has %i outputs.\n", crtc, info->noutput);
      
      if (info->noutput == 0)
        break;
    }

  return crtc;
}

- (NSSize)sizeInPixels
{
  return sizeInPixels;
}

- (NSSize)sizeInMilimeters
{
  return sizeInMilimeters;
}

- (NSUInteger)colorDepth
{
  Window root;
  int x, y;
  unsigned width, height, bw, depth;

  XGetGeometry (xDisplay, xRootWindow,
                &root, &x, &y, &width, &height, &bw, &depth);
  XSync (xDisplay, 0);

  return (NSUInteger)depth;
}

// Returns array of NXDisplay
- (NSArray *)allDisplays
{
  return systemDisplays;
}

- (NSArray *)activeDisplays
{
  NSMutableArray *activeDL = [[NSMutableArray alloc] init];
  
  for (NXDisplay *d in systemDisplays)
    {
      if ([d isActive])
        {
          [activeDL addObject:d];
        }
    }

  return activeDL;
}

- (NSArray *)connectedDisplays
{
  NSMutableArray *connectedDL = [[NSMutableArray alloc] init];
  
  for (NXDisplay *d in systemDisplays)
    {
      if ([d isConnected])
        {
          [connectedDL addObject:d];
        }
    }

  return connectedDL;
}

// TODO
- (NXDisplay *)mainDisplay
{
  NXDisplay *display;
  
  for (display in systemDisplays)
    {
      if ([display isActive] && [display isMain])
        break;
      display = nil;
    }
  
  return display;
}

// TODO
- (NXDisplay *)displayAtPoint:(NSPoint)point
{
  return [systemDisplays objectAtIndex:0];
}

- (NXDisplay *)displayWithName:(NSString *)name
{
  for (NXDisplay *display in systemDisplays)
    {
      if ([[display outputName] isEqualToString:name])
        return display;
    }

  return nil;
}

- (NXDisplay *)displayWithID:(id)uniqueID
{
  for (NXDisplay *display in systemDisplays)
    {
      if ([[display uniqueID] hash] == [uniqueID hash])
        return display;
    }

  return nil;
}

//---
// Layouts
//---
// Described by set of NXDisplay's with:
// - resolution and refresh rate (mode);
// - origin (position) - place displays aligned with each other;
// - rotation
// For example:
// 1. Latop with builtin monitor(1920x1080) has 1 NXDisplay with resolution set
//    to 1920x1080 and origin set to (0,0).
//    Screen size is: 1920x1080.
// 2. Laptop with connected external monitor (1280x1024) has 2 NXDisplays:
//    - builtin with resolution 1920x1080 and origin (0,0);
//    - external monitor with resolution 1280x1024 and origin (1920,0)
//    Screen size is: 3200x1080.

// Resolutions of all connected monitors will be set to preferred (first in
// list of supported) with  highest refresh rate for that
// resolution. Origin of first monitor in Xrandr list will be (0,0). Other
// monitors will lined horizontally from left to right (second monitor's
// origin X will be the width of first one, third's - sum of widths of first
// and second monitors etc.).
// All monitor's Y position = 0.
// All newly connected monitors will be placed rightmost (despite the current
// layout of existing monitors).
- (NSArray *)defaultLayout:(BOOL)arrange
{
  NSMutableDictionary   *d;
  NSMutableArray *layout = [NSMutableArray new];
  NSDictionary   *resolution;
  NSPoint        origin = NSMakePoint(0.0,0.0);
  
  for (NXDisplay *display in [self connectedDisplays])
    {
      resolution = [display preferredMode];
      
      d = [[NSMutableDictionary alloc] init];
      [d setObject:[display uniqueID] forKey:@"ID"];
      [d setObject:[display outputName] forKey:@"Name"];
      [d setObject:resolution forKey:@"Resolution"];
      [d setObject:NSStringFromPoint(origin) forKey:@"Origin"];
      [d setObject:NSStringFromSize([display physicalSize]) forKey:@"Size"];
      [d setObject:@"YES" forKey:@"Active"];
      [d setObject:([display isMain]) ? @"YES" : @"NO" forKey:@"Main"];
      
      [layout addObject:d];
      [d release];

      if (arrange)
        origin.x +=
          NSSizeFromString([resolution objectForKey:@"Dimensions"]).width;
    }

  return [layout copy];
}

- (NSArray *)currentLayout
{
  NSMutableDictionary *d;
  NSMutableArray      *layout = [NSMutableArray new];
  NSDictionary        *resolution;
  NSPoint             origin = NSMakePoint(0.0,0.0);
  
  for (NXDisplay *display in [self connectedDisplays])
    {
      d = [[NSMutableDictionary alloc] init];
      [d setObject:[display uniqueID] forKey:@"ID"];
      [d setObject:[display outputName] forKey:@"Name"];
      [d setObject:[display mode] forKey:@"Resolution"];
      [d setObject:NSStringFromPoint([display frame].origin) forKey:@"Origin"];
      [d setObject:NSStringFromSize([display physicalSize]) forKey:@"Size"];
      [d setObject:([display isActive]) ? @"YES" : @"NO" forKey:@"Active"];
      [d setObject:([display isMain]) ? @"YES" : @"NO" forKey:@"Main"];
      
      [layout addObject:d];
      [d release];
    }

  return layout;
}

- (void)applyDisplayLayout:(NSArray *)layout
{
  NSSize    newPixSize;
  NSSize    mmSize;
  BOOL      isGrowing = NO;
  NXDisplay *display;

  // Validate existance of all displays in 'layout'
  for (NSDictionary *displayLayout in layout)
    {
      if (![self displayWithID:[displayLayout objectForKey:@"ID"]])
        { // Some display is not connected - layout is not valid, apply default
          [self applyDisplayLayout:[self defaultLayout:YES]];
          NSLog(@"NXScreen:Applying default layout (Display.config ignored)");
          return;
        }
    }
  
  newPixSize = [self _sizeInPixelsForLayout:layout];
  mmSize = [self _sizeInMilimeters];
  NSLog(@"New screen size: %@, old %.0fx%.0f",
        NSStringFromSize(newPixSize), sizeInPixels.width, sizeInPixels.height);
  if (sizeInPixels.width < newPixSize.width ||
      sizeInPixels.height < newPixSize.height)
    {
      // Screen is getting bigger
      isGrowing = YES;
      XRRSetScreenSize(xDisplay, xRootWindow,
                       (int)newPixSize.width, (int)newPixSize.height,
                       (int)mmSize.width, (int)mmSize.height);
    }
  
  // Set resolution to displays
  for (NSDictionary *displayLayout in layout)
    {
      display = [self displayWithName:[displayLayout objectForKey:@"Name"]];
      if ([[displayLayout objectForKey:@"Active"] isEqualToString:@"NO"])
        {
          [display deactivate];
        }
      else
        {
          [display
            setResolution:[displayLayout objectForKey:@"Resolution"]
                   origin:NSPointFromString([displayLayout objectForKey:@"Origin"])];
        }
    }
        
  // Screen size gets smaller and must have changed after display
  // resolution changes.
  if (isGrowing == NO)
    {
      XRRSetScreenSize(xDisplay, xRootWindow,
                       (int)newPixSize.width, (int)newPixSize.height,
                       (int)mmSize.width, (int)mmSize.height);
    }

  XUngrabServer(xDisplay);

  sizeInPixels = [self _sizeInPixels];
  sizeInMilimeters = [self _sizeInMilimeters];
  
  [self _refreshDisplaysInfo];
}

@end