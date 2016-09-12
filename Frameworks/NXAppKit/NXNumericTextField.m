/*
  Class:               NXNumericTextField
  Inherits from:       NSTextField
  Class descritopn:    NSTextField wich accepts only digits.
                       By default entered value interpreted as integer.
                       Otherwise it must be set as float via 
                       setMinimum.../setMaximum... methods.

  Copyright (C) 2016 Sergii Stoian

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "NXNumericTextField.h"

@implementation NXNumericTextField (Private)

- (void)_setup
{
  [self setAlignment:NSRightTextAlignment];
  isDecimal = NO;
  minimumValue = -65535.0;
  maximumValue = 65535.0;

  formatter = [[NSNumberFormatter alloc] init];
  [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
  [formatter setMinimumIntegerDigits:1];
  [formatter setMinimumFractionDigits:0];
}

// Check for digits (0-9), minus (-) and period (.) signs.
- (BOOL)_isValidString:(NSString *)text
{
  NSCharacterSet *digitsCharset = [NSCharacterSet decimalDigitCharacterSet];
  
  for (int i = 0; i < [text length]; ++i)
    {
      if (([digitsCharset characterIsMember:[text characterAtIndex:i]] == NO)
          && ([text characterAtIndex:i] != '-')
          && ([text characterAtIndex:i] != '.'))
        {
          return NO;
        }
    }

  return YES;
}

@end

@implementation NXNumericTextField

//----------------------------------------------------------------------------
#pragma mark | Overridings
//----------------------------------------------------------------------------

- (id)init
{
  self = [super init];
  [self _setup];
  return self;}

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame:frameRect];
  [self _setup];
  return self;
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
  self = [super initWithCoder:aDecoder];
  [self _setup];
  return self;
}

- (void)dealloc
{
  [formatter release];
  [super dealloc];
}

- (void)setStringValue:(NSString *)aString
{
  CGFloat val = [aString floatValue];
  
  [super setStringValue:[formatter stringFromNumber:[NSDecimalNumber numberWithFloat:val]]];
}

- (BOOL)textShouldEndEditing:(NSText*)textObject
{
  CGFloat val = [[textObject string] floatValue];

  if (val < minimumValue) val = minimumValue;
  if (val > maximumValue) val = maximumValue;

  NSLog(@"Localized field value: '%@' - '%@'",
        [NSNumberFormatter
          localizedStringFromNumber:[NSDecimalNumber numberWithFloat:val]
                        numberStyle:NSNumberFormatterDecimalStyle],
        [formatter stringFromNumber:[NSDecimalNumber numberWithFloat:val]]);

  [self setStringValue:[formatter stringFromNumber:[NSDecimalNumber numberWithFloat:val]]];
  
  return YES;
}

- (void)keyDown:(NSEvent*)theEvent
{
  NSLog(@"NXNumericField: keyDown.");
}

- (void)keyUp:(NSEvent*)theEvent
{
  NSRange range;
  
  [super keyUp:theEvent];

  if ([theEvent keyCode] == 110)
    {
      range = [[self stringValue] rangeOfString:@"."];  
      if (range.location != NSNotFound)
        {
          // Select fraction part
          range.length = range.location;
          range.location = 0;
          [[[self window] fieldEditor:NO forObject:self]
                        setSelectedRange:range];
        }
    }
  
  NSLog(@"NXNumericField: keyUp - %u", [theEvent keyCode]);
}

//----------------------------------------------------------------------------
#pragma mark | NSTextView delegate
//----------------------------------------------------------------------------

/* Field editor (NSTextView) designates us as delegate. So we use delegate 
   methods to validate entered or pasted values. */
- (BOOL)	textView:(NSTextView *)textView
 shouldChangeTextInRange:(NSRange)affectedCharRange
       replacementString:(NSString *)replacementString
{
  BOOL    result = YES;
  NSRange range;

  if (!replacementString || [replacementString length] == 0)
    {
      return YES;
    }
  
  if ([self _isValidString:replacementString] == YES)
    {
      for (int i = 0; i < [replacementString length]; ++i)
        {
          if ([replacementString characterAtIndex:i] == '-')
            {
              if (i != 0 || affectedCharRange.location != 0
                  || [[self stringValue] rangeOfString:@"-"].location != NSNotFound)
                {
                  result = NO;
                  break;
                }
            }
          else if ([replacementString characterAtIndex:i] == '.')
            {
              if (!isDecimal)
                {
                  result = NO;
                  break;
                }
              else
                {
                  range = [[self stringValue] rangeOfString:@"."];
                  // Extra '.' want to be added
                  if (range.location != NSNotFound
                      && NSIntersectionRange(range, affectedCharRange).length == 0)
                    {
                      // Select fraction part
                      range.location += 1;
                      range.length = [[self stringValue] length] - range.location;
                      [[[self window] fieldEditor:NO forObject:self]
                        setSelectedRange:range];
                      result = NO;
                      break;
                    }
                }
            }
        }
    }
  else
    {
      NSLog(@"Invalid text was entered!");
      result = NO;
    }
  
  return result;
}


//----------------------------------------------------------------------------
#pragma mark | NSTextField additions
//----------------------------------------------------------------------------

- (void)setMinimumValue:(CGFloat)min
{
  minimumValue = min;
}

- (void)setMaximumValue:(CGFloat)max
{
  maximumValue = max;
}

- (void)setMaximumIntegerDigits:(NSUInteger)leftDigits
{
  [formatter setMaximumIntegerDigits:leftDigits];
}

- (void)setMinimumIntegerDigits:(NSUInteger)leftDigits
{
  [formatter setMinimumIntegerDigits:leftDigits];
}

- (void)setMaximumFractionDigits:(NSUInteger)rightDigits
{
  [formatter setMaximumFractionDigits:rightDigits];
  isDecimal = rightDigits > 0 ? YES : NO;
}

- (void)setMinimumFractionDigits:(NSUInteger)rightDigits
{
  [formatter setMinimumFractionDigits:rightDigits];
  isDecimal = rightDigits > 0 ? YES : NO;
}


@end