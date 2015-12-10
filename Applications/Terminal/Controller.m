/*
 *
 */
 
#import <sys/wait.h>

#import "Defaults.h"

#import "Services.h"
#import "ServicesPrefs.h"
#import "TerminalView.h"
#import "TerminalWindow.h"

#import "Controller.h"

//-----------------------------------------------------------------------------
// Child shells management
//-----------------------------------------------------------------------------
// static void child_action_handler(int signal, siginfo_t *siginfo, void *context)
// {
//   NSLog(@"Received signal %i: PID=%i error=%i status=%i",
//         signal, siginfo->si_pid,
//         siginfo->si_errno, siginfo->si_status);

//   [[NSApp delegate] childWithPID:siginfo->si_pid
//                          didExit:siginfo->si_status];
// }
// {
//   struct  sigaction child_action;
//   child_action.sa_sigaction = &child_action_handler;
//   child_action.sa_flags = SA_SIGINFO;
//   sigaction(SIGCHLD, &child_action, NULL);
// }  
//-----------------------------------------------------------------------------

@implementation Controller

- init
{
  if (!(self=[super init])) return nil;

  windows = [[NSMutableDictionary alloc] init];
  
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [windows release];

  [super dealloc];
}

// --- Menu
- (void)openPreferences:(id)sender
{
  [[Defaults shared] activatePanel];
}

- (void)openWindow:(id)sender
{
  [self newWindowWithShell];
}

// - (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
// {
//   NSString *menuTitle = [[menuItem menu] title];
//   NSWindow *keyWindow = [NSApp keyWindow];

//   // NSLog(@"Validate menu: %@ item: %@", menuTitle, [menuItem title]);

//   if ([menuTitle isEqualToString:@"Edit"])
//     {
//       if ([[menuItem title] isEqualToString:@"Clear Buffer"])
//         {
//           return NO;
//         }
//     }

//   return YES;
// }

// --- NSApplication delegate
- (void)applicationWillTerminate:(NSNotification *)n
{
}

- (void)applicationWillFinishLaunching:(NSNotification *)n
{
  [TerminalView registerPasteboardTypes];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(noMoreActiveWindows:)
	   name:TerminalWindowNoMoreActiveWindowsNotification
	 object:nil];
}


- (void)applicationDidFinishLaunching:(NSNotification *)n
{
  NSArray *args = [[NSProcessInfo processInfo] arguments];
    
  [NSApp setServicesProvider:[[TerminalServices alloc] init]];
  
  if ([args count] > 1)
    {
      TerminalWindowController *twc;
      NSString *cmdline;

      args = [args subarrayWithRange:NSMakeRange(1,[args count]-1)];
      cmdline = [args componentsJoinedByString:@" "];

      twc = [self newTerminalWindow];
      [[twc terminalView]
        runProgram:@"/bin/sh"
        withArguments:[NSArray arrayWithObjects:@"-c",cmdline,nil]
        initialInput:nil];
    }
  else if ([Defaults startupAction] == OnStartCreateShell)
    {
      [self openWindow:self];
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
  if (![self numberOfActiveWindows])
    {
      return NSTerminateNow;
    }

  [NSApp activateIgnoringOtherApps:YES];

  if (NSRunAlertPanel((@"Quit"),
		      (@"Do you really want to quit application?"),
		      (@"Don't quit"), (@"Quit"), nil)
      == NSAlertAlternateReturn)
    {
      return NSTerminateNow;
    }

  return NSTerminateLater;
}

- (void)quitAnyway:(id)sender
{
  [NSApp replyToApplicationShouldTerminate:YES];
}

- (void)dontQuit:(id)sender
{
  [NSApp replyToApplicationShouldTerminate:NO];
}

- (BOOL)application:(NSApplication *)sender
 	   openFile:(NSString *)filename
{
  TerminalWindowController *twc;

  NSDebugLLog(@"Application",@"openFile: '%@'",filename);

  // TODO: shouldn't ignore other apps

  [NSApp activateIgnoringOtherApps:YES];

  twc = [self newTerminalWindow];
  [[twc terminalView] runProgram:filename
		   withArguments:nil
		    initialInput:nil];

  return YES;
}


// TODO
- (BOOL)terminalRunProgram:(NSString *)path
	     withArguments:(NSArray *)args
	       inDirectory:(NSString *)directory
		properties:(NSDictionary *)properties
{
  TerminalWindowController *twc;

  NSDebugLLog(@"Application",
	      @"terminalRunProgram: %@ withArguments: %@ inDirectory: %@ properties: %@",
	      path,args,directory,properties);

  // TODO: shouldn't ignore other apps

  [NSApp activateIgnoringOtherApps:YES];

  {
    id o;
    o=[properties objectForKey: @"CloseOnExit"];
    if (o && [o respondsToSelector: @selector(boolValue)] &&
        ![o boolValue])
      {
        twc = [self idleTerminalWindow];
      }
    else
      {
        twc = [self newTerminalWindow];
      }
  }

  [[twc terminalView] runProgram:path
		   withArguments:args
		     inDirectory:directory
		    initialInput:nil
			    arg0:nil];

  return YES;
}

// TODO
- (BOOL)terminalRunCommand:(NSString *)cmdline
	       inDirectory:(NSString *)directory
		properties:(NSDictionary *)properties
{
  NSDebugLLog(@"Application",
	      @"terminalRunCommand: %@ inDirectory: %@ properties: %@",
	      cmdline,directory,properties);

  return [self terminalRunProgram:@"/bin/sh"
		    withArguments:[NSArray arrayWithObjects: @"-c",cmdline,nil]
		      inDirectory:directory
		       properties:properties];
}

@end

//-----------------------------------------------------------------------------
// Child shells management
//---
// Role of these methods are to create, monitor and close terminal windows
//-----------------------------------------------------------------------------
@implementation Controller (TerminalController)

- (void)childWithPID:(int)pid didExit:(int)status
{
  TerminalWindowController *twc;
  int windowCloseBehavior = [Defaults windowCloseBehavior];

  NSLog(@"Child with pid: %i did exit(%i)", pid, status);
  
  twc = [windows objectForKey:[NSString stringWithFormat:@"%i",pid]];
  [twc setDocumentEdited:NO];
  
  if (windowCloseBehavior != WindowCloseNever)
    {
      if ((windowCloseBehavior == WindowCloseAlways) || (status == 0))
        {
          [twc close];
        }
    }
}

- (void)checkWindowsState
{
  if ([windows count] <= 0)
    {
      [timer invalidate];
      timer = nil;
      return;
    }

  NSArray *wins = [windows allValues];

  for (TerminalWindowController *twc in wins)
    {
      if ([[twc terminalView] isUserProgramRunning])
        {
          [twc setDocumentEdited:YES];
        }
      else
        {
          [twc setDocumentEdited:NO];
        }
    }
}

- (void)noMoreActiveWindows:(NSNotification *)n
{
  if (quitPanelOpen) 
    {
      [NSApp replyToApplicationShouldTerminate:YES];
    }
}

- (int)numberOfActiveWindows
{
  return [windows count] - [idleList count];
}

- (void)checkActiveWindows
{
  if (![self numberOfActiveWindows])
    {
      [[NSNotificationCenter defaultCenter]
			postNotificationName:TerminalWindowNoMoreActiveWindowsNotification
                                      object:self];
    }
}

- (int)pidForWindow:(TerminalWindowController *)twc
{
  NSArray *keys = [windows allKeys];
  int     pid = -1;
 
  for (NSString *PID in keys)
    {
      if ([windows objectForKey:PID] == twc)
        {
          pid = [PID integerValue]; 
        }
    }

  return pid;
}

- (void)window:(TerminalWindowController *)twc becameIdle:(BOOL)idle
{
  if (idle)
    {
      int pid, status;
      
      [idleList addObject:twc];
      
      if ((pid = [self pidForWindow:twc]) > 0)
        {
          // fprintf(stderr, "Idle: Waiting for PID: %i...", pid);
          waitpid(pid, &status, 0);
          // fprintf(stderr, "\tdone!\n");
          
          // [self childWithPID:pid didExit:status];
          int windowCloseBehavior = [Defaults windowCloseBehavior];
          [twc setDocumentEdited:NO];

          windowCloseBehavior = [twc closeBehavior];
          if (windowCloseBehavior != WindowCloseNever)
            {
              if ((windowCloseBehavior == WindowCloseAlways) || (status == 0))
                {
                  [twc close];
                }
            }
        }
    }
  else
    {
      [idleList removeObject:twc];
    }

  
  [[NSApp delegate] checkActiveWindows];
}

// TODO: TerminalWindowDidCloseNotification -> windowDidClose:(NSNotification*)n
- (void)closeWindow:(TerminalWindowController *)twc
{
  int pid, status;
  
  if ([idleList containsObject:twc])
    [idleList removeObject:twc];

  if ((pid = [self pidForWindow:twc]) > 0)
    {
      kill(pid, SIGKILL);
      // fprintf(stderr, "Close: Waiting for PID: %i...", pid);
      waitpid(pid, &status, 0);
      // fprintf(stderr, "\tdone!\n");
      
      [windows removeObjectForKey:[NSString stringWithFormat:@"%i", pid]];
    }
   
  [[NSApp delegate] checkActiveWindows];
}

// TODO:
// Terminal window can be run in 2 modes: 'Shell' and 'Program' (now it's
// called 'Idle').
// 
// In 'Shell' mode running shell is not considered as running program
// (close window button has normal state). Close window button change its state
// to 'document edited' until some program executed in the shell (as aresult
// shell has child process).
// 
// In 'Program' mode any programm executed considered as important and close
// window button has 'document edited' state. This button changes its state
// to normal when running program finishes.
// Also in 'Program' mode window will never close despite the 'When Shell Exits'
// preferences setting.
// + (TerminalWindowController *)newWindowWithProgram:(NSString *)path
// {
// }

- (TerminalWindowController *)newTerminalWindow
{
  TerminalWindowController *twc;

  twc = [[TerminalWindowController alloc] init];
  [twc setDocumentEdited:YES];
  
  NSArray *wins = [windows allValues];
  if ([wins count] > 0)
    {
      NSRect  mwFrame = [[NSApp mainWindow] frame];
      NSPoint wOrigin = mwFrame.origin;

      wOrigin.x += [NSScroller scrollerWidth]+3;
      wOrigin.y -= 24;
      [[twc window] setFrameOrigin:wOrigin];
    }
  else
    {
      [[twc window] center];
    }
  
  [twc showWindow:self];

  return twc;
}

- (TerminalWindowController *)newWindowWithShell
{
  TerminalWindowController *twc = [self newTerminalWindow];
  int pid;

  if (twc == nil) return nil;

  pid = [[twc terminalView] runShell];
  [windows setObject:twc forKey:[NSString stringWithFormat:@"%i",pid]];

  if (timer == nil)
    {
      timer =
        [NSTimer scheduledTimerWithTimeInterval:2.0
                                         target:self
                                       selector:@selector(checkWindowsState)
                                       userInfo:nil
                                        repeats:YES];
    }

  return twc;
}

- (TerminalWindowController *)idleTerminalWindow
{
  NSDebugLLog(@"idle",@"get idle window from idle list: %@",idleList);
  
  if ([idleList count])
    return [idleList objectAtIndex:0];
  
  return [self newTerminalWindow];
}


@end