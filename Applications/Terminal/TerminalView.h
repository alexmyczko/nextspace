/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>

This file is a part of Terminal.app. Terminal.app is free software; you
can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation; version 2
of the License. See COPYING or main.m for more information.
*/

#ifndef TerminalView_h
#define TerminalView_h

#import <AppKit/NSView.h>
#import <Foundation/NSFileHandle.h>


extern NSString
	*TerminalViewBecameIdleNotification,
	*TerminalViewBecameNonIdleNotification,
	*TerminalViewTitleDidChangeNotification;

#include "Terminal.h"
#import "TerminalParser_Linux.h"

/* TODO: this is slightly ugly */
//@class TerminalParser_Linux;

@class NSScroller;

struct selection_range
{
  int location,length;
};

@interface TerminalView : NSView
{
  NSString *programPath;
  NSString *childTerminalName;
  int      childPID;
  
  NSScroller *scroller;
  BOOL       scroll_bottom_on_input;

  NSFont *font,*boldFont;
  int    font_encoding, boldFont_encoding;
  BOOL   use_multi_cell_glyphs;
  float  fx,fy,fx0,fy0;

  BOOL blackOnWhite;

  struct
    {
      int x0,y0,x1,y1;
    } dirty;

  int master_fd;
  NSFileHandle *masterFDHandle;

  unsigned char *write_buf;
  int write_buf_len,write_buf_size;

  int max_scrollback;
  int sb_length, current_scroll;
  screen_char_t *sbuf;

  int sx,sy;
  screen_char_t *screen;

  int cursor_x,cursor_y;
  int current_x,current_y;

  NSString *title_window,*title_miniwindow;

  NSObject<TerminalParser> *tp;

  int  draw_all; /* 0=only lazy, 1=don't know, do all, 2=do all */
  BOOL draw_cursor;

  struct selection_range selection;

  /* scrolling by compositing takes a long while, so we break out of such
     loops fairly often to process other events */
  int num_scrolls;

  /* To avoid doing lots of scrolling compositing, we combine multiple
     full-screen scrolls. pending_scroll is the combined pending line delta */
  int pending_scroll;

  BOOL ignore_resize;

  float border_x,border_y;
}

- (void)setIgnoreResize:(BOOL)ignore;

- (void)setBorder: (float)x : (float)y;

- (void)setFont:(NSFont *)aFont;
- (void)setBoldFont:(NSFont *)bFont;
- (int)scrollBufferLength;
- (void)setScrollBufferMaxLength:(int)lines;
- (void)setScrollBottomOnInput:(BOOL)scrollBottom;
- (void)setUseMulticellGlyphs:(BOOL)multicellGlyphs;
- (void)setCursorStyle:(NSUInteger)style;

- (NSString *)shellPath;
- (NSString *)deviceName;
- (NSString *)windowSize;
  
- (NSString *)windowTitle;
- (NSString *)miniwindowTitle;
- (BOOL)isUserProgramRunning;

+ (void)registerPasteboardTypes;

@end

@interface TerminalView (display) <TerminalScreen>
- (void)updateColors:(NSDictionary *)prefs;
- (void)setNeedsLazyDisplayInRect:(NSRect)r;
@end

/* TODO: this is ugly */
@interface TerminalView (scrolling_2)
- (void)setScroller:(NSScroller *)sc;
@end

@interface TerminalView (input_2)
- (void)readData;

- (void)closeProgram;

// Next 3 methods return PID of program
- (int)runProgram:(NSString *)path
    withArguments:(NSArray *)args
     initialInput:(NSString *)d;
- (int)runProgram:(NSString *)path
    withArguments:(NSArray *)args
      inDirectory:(NSString *)directory
     initialInput:(NSString *)d
             arg0:(NSString *)arg0;
- (int)runShell;
@end

#endif
