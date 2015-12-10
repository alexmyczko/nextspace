/*
  copyright 2002, 2003 Alexander Malmberg <alexander@malmberg.org>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import <math.h>
#import <sys/wait.h>

#import <Foundation/NSDebug.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSString.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSScroller.h>
#import <AppKit/NSWindow.h>

#import "TerminalWindow.h"
#import "Controller.h"
#import "TerminalView.h"

NSString *TerminalWindowNoMoreActiveWindowsNotification=
    @"TerminalWindowNoMoreActiveWindowsNotification";

// Window
static int terminalColumns;
static int terminalRows;
static WindowCloseBehavior windowCloseBehavior;

// Title Bar
static NSUInteger titleBarElementsMask;
static NSString   *titleBarCustomTitle;

// Display
static BOOL scrollBackEnabled;
// static BOOL scrollBackUnlimited;
// static int  scrollBackLines;
// static BOOL scrollBottomOnInput;

static int    scrollerWidth;
static NSSize charCellSize;
static NSSize winContentSize;
static NSSize winMinimumSize;

@implementation TerminalWindowController

- (void)calculateSizes
{
  // Scroller
  scrollerWidth = (scrollBackEnabled==YES) ? [NSScroller scrollerWidth] : 0;

  // calc the rects for our window
  winContentSize =
    NSMakeSize(charCellSize.width  * terminalColumns + scrollerWidth + 1,
               charCellSize.height * terminalRows + 1);
  winMinimumSize =
    NSMakeSize(charCellSize.width  * MIN_COLUMNS + scrollerWidth + 1,
               charCellSize.height * MIN_LINES + 1);
  // add the borders to the size
  winContentSize.width += 8;
  winContentSize.height += 3;
  winMinimumSize.width += 8;
  winMinimumSize.height += 3;

  return;
}

- init
{
  NSRect     contentRect, windowRect;
  NSUInteger styleMask;

  // Make cache of preferences
  scrollBackEnabled = [Defaults scrollBackEnabled];
  terminalRows = [Defaults windowHeight];
  terminalColumns = [Defaults windowWidth];
  titleBarElementsMask = [Defaults titleBarElementsMask];
  titleBarCustomTitle = [Defaults customTitle];

  // Sizes
  charCellSize = [Defaults characterCellSizeForFont:nil];
  [self calculateSizes];
  
  windowCloseBehavior = [Defaults windowCloseBehavior];

  contentRect = NSMakeRect(0, 0, winContentSize.width, winContentSize.height);
  styleMask = (NSClosableWindowMask  | NSTitledWindowMask |
               NSResizableWindowMask | NSMiniaturizableWindowMask);
  win = [[NSWindow alloc] initWithContentRect:contentRect
                                    styleMask:styleMask
                                      backing:NSBackingStoreRetained
                                        defer:YES];
  
  if (!(self = [super initWithWindow:win])) return nil;

  windowRect = [win frame];
  winMinimumSize.width += windowRect.size.width - winContentSize.width;
  winMinimumSize.height += windowRect.size.height - winContentSize.height;
  
  [win setTitle:titleBarCustomTitle];
  [win setDelegate:self];

  [win setContentSize:winContentSize];
  [win setResizeIncrements:NSMakeSize(charCellSize.width, charCellSize.height)];
  [win setMinSize:winMinimumSize];

  hBox = [[GSHbox alloc] init];

  // Scroller
  scroller = [[NSScroller alloc] initWithFrame:NSMakeRect(0,0,scrollerWidth,
                                                          charCellSize.height)];
  [scroller setArrowsPosition:NSScrollerArrowsMaxEnd];
  [scroller setEnabled:YES];
  [scroller setAutoresizingMask:NSViewHeightSizable];
  if (scrollBackEnabled)
    {
      [hBox addView:scroller enablingXResizing:NO];
      [scroller release];
    }

  // View
  tView = [[TerminalView alloc] init];
  [tView setIgnoreResize:YES];
  [tView setAutoresizingMask:NSViewHeightSizable|NSViewWidthSizable];
  [tView setScroller:scroller];
  [hBox addView:tView];
  [tView release];
  [tView setIgnoreResize:NO];
  [win makeFirstResponder:tView];

  // if ([ud boolForKey:@"AddYBorders"])
  //   [tView setBorder:4 :4];
  // else
    [tView setBorder:4 :2];

  [win setContentView:hBox];
  DESTROY(hBox);
  
  [win release];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(preferencesDidChange:)
           name:TerminalPreferencesDidChangeNotification
         object:win];
  
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(viewBecameIdle)
           name:TerminalViewBecameIdleNotification
         object:tView];
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(viewBecameNonIdle)
           name:TerminalViewBecameNonIdleNotification
         object:tView];
  
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(updateTitleBar:)
           name:TerminalViewTitleDidChangeNotification
         object:tView];

  return self;
}

- (void)dealloc
{
  NSLog(@"Window DEALLOC.");
  
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

// --- Accessories ---
- (TerminalView *)terminalView
{
  return tView;
}

- (WindowCloseBehavior)closeBehavior
{
  return windowCloseBehavior;
}

// Title Bar elements
- (NSString *)shellPath
{
  return [tView shellPath];
}

- (NSString *)deviceName
{
  return [tView deviceName];
}

- (NSString *)fileName
{
  return @"Default";
}

- (NSString *)windowSize
{
  return [tView windowSize];
}

// --- Notifications ---
- (void)updateTitleBar:(NSNotification *)n
{
  NSString *title;

  if (titleBarElementsMask & TitleBarCustomTitle)
    {
      [win setTitle:titleBarCustomTitle];
      [win setMiniwindowTitle:titleBarCustomTitle];
      return;
    }
  
  title = [NSString new];
  
  if (titleBarElementsMask & TitleBarShellPath)
    title = [title stringByAppendingFormat:@"%@ ", [tView shellPath]];
  
  if (titleBarElementsMask & TitleBarDeviceName)
    title = [title stringByAppendingFormat:@"(%@) ", [tView deviceName]];
  
  if (titleBarElementsMask & TitleBarWindowSize)
    title = [title stringByAppendingFormat:@"%@ ", [tView windowSize]];
  
  if (titleBarElementsMask & TitleBarFileName)
    {
      if ([title length] == 0)
        {
          title = [title stringByAppendingFormat:@"Terminal \u2014 %@",
                         [self fileName]];
        }
      else
        {
          title = [title stringByAppendingFormat:@"\u2014 %@", [self fileName]];
        }
    }

  [win setTitle:title];
  [win setMiniwindowTitle:[tView shellPath]];
}

- (void)windowWillClose:(NSNotification *)n
{
  NSLog(@"Window WILL close.");

  [tView closeProgram];

  [[NSApp delegate] closeWindow:self];
  
  [self autorelease];
}

- (BOOL)windowShouldClose:(id)sender
{
  NSLog(@"Window SHOULD close.");
  if ([[self window] isDocumentEdited])
    {
      if (NSRunAlertPanel(@"Close",
                          @"Closing this window will terminate"
                          @" running process(es) inside it.",
                          @"Cancel", @"Close anyway", nil)
          == NSAlertDefaultReturn)
        {
          return NO;
        }
    }

  return YES;
}

- (void)viewBecameIdle
{
  NSString *t;

  NSDebugLLog(@"idle",@"%@ _becameIdle",self);

  t = [[self window] title];
  t = [t stringByAppendingString:_(@" (idle)")];
  [[self window] setTitle:t];

  t = [[self window] miniwindowTitle];
  t = [t stringByAppendingString:_(@" (idle)")];
  [[self window] setMiniwindowTitle:t];
  
  [[NSApp delegate] window:self becameIdle:YES];
}

- (void)viewBecameNonIdle
{
  NSDebugLLog(@"idle",@"%@ _becameNonIdle",self);
  
  [[NSApp delegate] window:self becameIdle:NO];
}

- (void)preferencesDidChange:(NSNotification *)notif
{
  NSDictionary *prefs = [notif userInfo];
  id           value;
  BOOL         isWindowSizeChanged = NO;

  //--- For Window usage only ---
  if ((value = [prefs objectForKey:WindowHeightKey]) &&
      [value intValue] != terminalRows)
    {
      terminalRows = [value intValue];
      isWindowSizeChanged = YES;
    }
  if ((value = [prefs objectForKey:WindowWidthKey]) &&
      [value intValue] != terminalColumns)
    {
      terminalColumns = [value intValue];
      isWindowSizeChanged = YES;
    }

  if ((value = [prefs objectForKey:TitleBarElementsMaskKey]) &&
      [value intValue] != titleBarElementsMask)
    {
      titleBarElementsMask = [value intValue];
      titleBarCustomTitle = [prefs objectForKey:TitleBarCustomTitleKey];
      [self updateTitleBar:nil];
    }
  
  if ((value = [prefs objectForKey:WindowCloseBehaviorKey]))
    windowCloseBehavior = [value intValue];

  //--- For Window and View usage ---
  if ((value = [prefs objectForKey:ScrollBackEnabledKey]) &&
      [value boolValue] != scrollBackEnabled)
    {
      scrollBackEnabled = [value boolValue];
      if (scrollBackEnabled == YES)
        {
          [tView retain];
          [tView removeFromSuperview];
          [hBox release];
          hBox = [[GSHbox alloc] init];

          [hBox addView:scroller enablingXResizing:NO];
          [scroller release];
          [hBox addView:tView];
          [tView release];
        }
      else
        {
          [tView retain];
          [tView removeFromSuperview];
          [scroller retain];
          [scroller removeFromSuperview];
          [hBox release];
          hBox = [[GSHbox alloc] init];
          
          [hBox addView:tView];
          [tView release];
        }
      [win setContentView:hBox];
      isWindowSizeChanged = YES;
    }

  if ((value = [prefs objectForKey:ScrollBackLinesKey]))
    {
      if (scrollBackEnabled == YES)
        [tView setScrollBufferMaxLength:[value intValue]];
      else
        [tView setScrollBufferMaxLength:0];
    }
  
  //---  For TerminalView usage only ---
  if ((value = [prefs objectForKey:TerminalFontKey]))
    {
      [tView setFont:[value screenFont]];
      [tView setBoldFont:[Defaults boldTerminalFontForFont:value]];
      charCellSize = [Defaults characterCellSizeForFont:value];
      isWindowSizeChanged = YES;
      [tView setNeedsDisplay:YES];
    }

  // Title Bar:
  // Display:
  if ((value = [prefs objectForKey:ScrollBottomOnInputKey]))
    {
      [tView setScrollBottomOnInput:[value boolValue]];
    }
  // Linux:
  if ((value = [prefs objectForKey:UseMultiCellGlyphsKey]))
    {
      [tView setUseMulticellGlyphs:[value boolValue]];
    }
  // Colors:
  if ((value = [prefs objectForKey:CursorColorKey]))
    {
      [tView setCursorStyle:[[prefs objectForKey:CursorStyleKey] integerValue]];
      [tView updateColors:prefs];
      [tView setNeedsDisplayInRect:[tView frame]];
    }

  //---  For TerminalParser usage only ---
  // TODO: First, GNUstep defaults should have reasonable settings (see
  // comment in terminal parser about Command, Alternat and Control modifiers).
  // The best way is to create Preferences' Keyboard panel.
  // if ((value = [prefs objectForKey:CharacterSetKey]))
  // if ((value = [prefs objectForKey:CommandAsMetaKey]))
  // if ((value = [prefs objectForKey:DoubleEscapeKey]))
  if (isWindowSizeChanged)
    {
      [self calculateSizes];
      [win setContentSize:winContentSize];
    }
}

// --- Actions ---
- (void)changeFont:(id)sender
{
  NSLog(@"TerminalWindow: changeFont:%@", [sender className]);
  if ([sender isKindOfClass:[NSFontManager class]]) // Font Panel
    {
    }
  else if ([sender isKindOfClass:[NSFont class]])   // Preferences
    {
    }
}

@end