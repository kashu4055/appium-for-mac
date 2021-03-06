//
//  AppiumMacController.m
//  AppiumAppleScriptProxy
//
//  Created by Dan Cuellar on 7/28/13.
//  Copyright (c) 2013 Appium. All rights reserved.
//

#import "AfMHandlers.h"

#import "AfMElementLocator.h"
#import "AppiumMacHTTP303JSONResponse.h"
#import "NSData+Base64.h"
#import "Utility.h"

@implementation AfMHandlers
- (id)init
{
    self = [super init];
    if (self) {
        [self setSessions:[NSMutableDictionary new]];
    }
    return self;
}

-(AfMSessionController*) controllerForSession:(NSString*)sessionId
{
    return [self.sessions objectForKey:sessionId];
}

-(NSDictionary*) dictionaryFromPostData:(NSData*)postData
{
    if (!postData)
    {
        return [NSDictionary new];
    }

    NSError *error = nil;
    NSDictionary *postDict = [NSJSONSerialization JSONObjectWithData:postData options:NSJSONReadingMutableContainers error:&error];

    // TODO: error handling
    return postDict;
}

-(AppiumMacHTTPJSONResponse*) respondWithJson:(id)json status:(int)status session:(NSString*)session
{
    return [self respondWithJson:json status:status session:session statusCode:200];
}

-(AppiumMacHTTPJSONResponse*) respondWithJson:(id)json status:(int)status session:(NSString*)session statusCode:(NSInteger)statusCode
{
    NSMutableDictionary *responseJson = [NSMutableDictionary new];
    [responseJson setValue:[NSNumber numberWithInt:status] forKey:@"status"];
    if (session != nil)
    {
        [responseJson setValue:session forKey:@"sessionId"];
    }
    [responseJson setValue:json forKey:@"value"];

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:responseJson
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    if (!jsonData)
    {
        NSLog(@"Got an error: %@", error);
        jsonData = [NSJSONSerialization dataWithJSONObject:
                    [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:-1], @"status", session, @"session", [NSString stringWithFormat:@"%@", error], @"value" , nil]
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&error];
    }
    switch (statusCode)
    {
        case 303:
            return [[AppiumMacHTTP303JSONResponse alloc] initWithData:jsonData];
        default:
            return [[AppiumMacHTTPJSONResponse alloc] initWithData:jsonData];
    }
}

// GET /status
-(AppiumMacHTTPJSONResponse*) getStatus:(NSString*)path
{
    NSDictionary *buildJson = [NSDictionary dictionaryWithObjectsAndKeys:[Utility bundleVersion], @"version", [Utility bundleRevision], @"revision", [NSString stringWithFormat:@"%d", [Utility unixTimestamp]], @"time", nil];
    NSDictionary *osJson = [NSDictionary dictionaryWithObjectsAndKeys:[Utility arch], @"arch", @"Mac OS X", @"name", [Utility version], @"version", nil];
    NSDictionary *json = [NSDictionary dictionaryWithObjectsAndKeys:buildJson, @"build", osJson, @"os", nil];
    return [self respondWithJson:json status:0 session:nil];
}

// POST /session
-(AppiumMacHTTPJSONResponse*) postSession:(NSString*)path data:(NSData*)postData
{
    // generate new session key
    NSString *newSession = [Utility randomStringOfLength:8];
    while ([self.sessions objectForKey:newSession] != nil)
    {
        newSession = [Utility randomStringOfLength:8];
    }

    [self.sessions setValue:[AfMSessionController new] forKey:newSession];

    // respond with the session
    // TODO: Add capabilities support
    // set empty capabilities for now
    return [self respondWithJson:@"" status:0 session: newSession];
}

// GET /sessions
-(AppiumMacHTTPJSONResponse*) getSessions:(NSString*)path
{
    // respond with the session
    // TODO: implement this correctly
    NSMutableArray *json = [NSMutableArray new];
    for(id key in self.sessions)
    {
        [json addObject:[NSDictionary dictionaryWithObjectsAndKeys:key, @"id", [self.sessions objectForKey:key], @"capabilities", nil]];
    }

    return [self respondWithJson:json status:0 session: nil];
}

// GET /session/:sessionId
-(AppiumMacHTTPJSONResponse*) getSession:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    // TODO: show error if session does not exist
    return [self respondWithJson:[self.sessions objectForKey:sessionId] status:0 session:sessionId];
}

// DELETE /session/:sessionId
-(AppiumMacHTTPJSONResponse*) deleteSession:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    if ([self.sessions objectForKey:sessionId] != nil)
    {
        [self.sessions removeObjectForKey:sessionId];
    }
    return [self respondWithJson:nil status:0 session: sessionId];
}

// /session/:sessionId/timeouts
// /session/:sessionId/timeouts/async_script
// /session/:sessionId/timeouts/implicit_wait

// GET /session/:sessionId/window_handle
-(AppiumMacHTTPJSONResponse*) getWindowHandle:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    return [self respondWithJson:session.currentWindowHandle status:0 session: sessionId];
}

// GET /session/:sessionId/window_handles
-(AppiumMacHTTPJSONResponse*) getWindowHandles:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    // TODO: add error handling
    return [self respondWithJson:session.allWindowHandles status:0 session: sessionId];
}

// GET /session/:sessionId/url
-(AppiumMacHTTPJSONResponse*) getUrl:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    return [self respondWithJson:session.currentApplicationName status:0 session: sessionId];
}

// POST /session/:sessionId/url
-(AppiumMacHTTPJSONResponse*) postUrl:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSDictionary *postParams = [self dictionaryFromPostData:postData];

    // activate supplied application

    NSString *url = (NSString*)[postParams objectForKey:@"url"];
    [session activateApplication:url];
    [session setCurrentApplicationName:url];
    [session setCurrentProcessName:[session processNameForApplicationName:url]];

    // TODO: error handling
    return [self respondWithJson:nil status:0 session: sessionId];
}

// /session/:sessionId/forward
// /session/:sessionId/back
// /session/:sessionId/refresh
// /session/:sessionId/execute
// /session/:sessionId/execute_async

// GET /session/:sessionId/screenshot
-(HTTPDataResponse*) getScreenshot:(NSString*)path
{
    system([@"/usr/sbin/screencapture -c" UTF8String]);
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *classArray = [NSArray arrayWithObject:[NSImage class]];
    NSDictionary *options = [NSDictionary dictionary];

    BOOL foundImage = [pasteboard canReadObjectForClasses:classArray options:options];
    if (foundImage)
    {
        NSArray *objectsToPaste = [pasteboard readObjectsForClasses:classArray options:options];
        NSImage *image = [objectsToPaste objectAtIndex:0];
        NSString *base64Image = [[image TIFFRepresentation] base64EncodedString];
        return [self respondWithJson:base64Image status:0 session:[Utility getSessionIDFromPath:path]];
    }
    else
    {
        return [self respondWithJson:nil status:0 session: [Utility getSessionIDFromPath:path]];
    }
}

// /session/:sessionId/ime/available_engines
// /session/:sessionId/ime/active_engine
// /session/:sessionId/ime/activated
// /session/:sessionId/ime/deactivate
// /session/:sessionId/ime/activate
// /session/:sessionId/frame

// POST /session/:sessionId/window
-(AppiumMacHTTPJSONResponse*) postWindow:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSDictionary *postParams = [self dictionaryFromPostData:postData];

    // activate application for supplied process
    NSString *windowHandle = (NSString*)[postParams objectForKey:@"name"];
    [session activateWindow:windowHandle forProcessName:session.currentProcessName];

    // TODO: error handling
    return [self respondWithJson:nil status:0 session: sessionId];
}

// DELETE /session/:sessionId/window
-(AppiumMacHTTPJSONResponse*) deleteWindow:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];

    [session closeWindow:session.currentWindowHandle forProcessName:session.currentProcessName];

    // TODO: error handling
    return [self respondWithJson:nil status:0 session: sessionId];
}

// POST /session/:sessionId/window/:windowHandle/size
-(AppiumMacHTTPJSONResponse*) postWindowSize:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
	NSString *windowHandle = [Utility getItemFromPath:path withSeparator:@"window"];
	SystemEventsWindow *window = [session windowForHandle:windowHandle forProcess:session.currentProcessName];

	NSDictionary *postParams = [self dictionaryFromPostData:postData];
    CGFloat width = [(NSNumber*)[postParams objectForKey:@"width"] floatValue];
	CGFloat height = [(NSNumber*)[postParams objectForKey:@"height"] floatValue];

	NSRect bounds = window.bounds;
	bounds.size.width = width;
	bounds.size.height = height;

	[window setBounds:bounds];
	
    // TODO: error handling
    return [self respondWithJson:nil status:0 session: sessionId];
}

// GET /session/:sessionId/window/:windowHandle/size
-(AppiumMacHTTPJSONResponse*) getWindowSize:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
	NSString *windowHandle = [Utility getItemFromPath:path withSeparator:@"window"];
	SystemEventsWindow *window = [session windowForHandle:windowHandle forProcess:session.currentProcessName];

	NSRect bounds = window.bounds;

    // TODO: error handling
    return [self respondWithJson:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:bounds.size.width], "width", [NSNumber numberWithFloat:bounds.size.height], @"height", nil] status:0 session: sessionId];
}

// POST /session/:sessionId/window/:windowHandle/position
-(AppiumMacHTTPJSONResponse*) postWindowPosition:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
	NSString *windowHandle = [Utility getItemFromPath:path withSeparator:@"window"];
	SystemEventsWindow *window = [session windowForHandle:windowHandle forProcess:session.currentProcessName];

	NSDictionary *postParams = [self dictionaryFromPostData:postData];
    CGFloat x = [(NSNumber*)[postParams objectForKey:@"x"] floatValue];
	CGFloat y = [(NSNumber*)[postParams objectForKey:@"y"] floatValue];

	NSRect bounds = window.bounds;
	bounds.origin.x = x;
	bounds.origin.y = y;

	[window setBounds:bounds];
	
    // TODO: error handling
    return [self respondWithJson:nil status:0 session: sessionId];
}

// GET /session/:sessionId/window/:windowHandle/position
-(AppiumMacHTTPJSONResponse*) getWindowPosition:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
	NSString *windowHandle = [Utility getItemFromPath:path withSeparator:@"window"];
	SystemEventsWindow *window = [session windowForHandle:windowHandle forProcess:session.currentProcessName];

	NSRect bounds = window.bounds;

    // TODO: error handling
    return [self respondWithJson:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat:bounds.origin.x], "x", [NSNumber numberWithFloat:bounds.origin.y], @"y", nil] status:0 session: sessionId];
}

// /session/:sessionId/window/:windowHandle/maximize
// /session/:sessionId/cookie
// /session/:sessionId/cookie/:name

// GET /session/:sessionId/source
-(AppiumMacHTTPJSONResponse*) getSource:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    return [self respondWithJson:[session pageSource] status:0 session: sessionId];
}

// /session/:sessionId/title

// POST /session/:sessionId/element
-(AppiumMacHTTPJSONResponse*) postElement:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSDictionary *postParams = [self dictionaryFromPostData:postData];

    NSString *using = (NSString*)[postParams objectForKey:@"using"];
    NSString *value = (NSString*)[postParams objectForKey:@"value"];

	AfMElementLocator *locator = [AfMElementLocator locatorWithSession:session using:using value:value];
	
	if (locator != nil)
	{
		SystemEventsUIElement *element = [locator findUsingBaseElement:nil];
        if (element != nil)
        {
            session.elementIndex++;
            NSString *myKey = [NSString stringWithFormat:@"%d", session.elementIndex];
            [session.elements setValue:element forKey:myKey];
            return [self respondWithJson:[NSDictionary dictionaryWithObject:myKey forKey:@"ELEMENT"] status:0 session:sessionId];
        }
	}
	
	// TODO: add error handling
	// TODO: move element id code into session controller

    return [self respondWithJson:nil status:-1 session: sessionId];
}

// POST /session/:sessionId/elements
-(AppiumMacHTTPJSONResponse*) postElements:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSDictionary *postParams = [self dictionaryFromPostData:postData];

    NSString *using = (NSString*)[postParams objectForKey:@"using"];
    NSString *value = (NSString*)[postParams objectForKey:@"value"];

	AfMElementLocator *locator = [AfMElementLocator locatorWithSession:session using:using value:value];
	
	if (locator != nil)
	{
		NSMutableArray *matches = [NSMutableArray new];
		[locator findAllUsingBaseElement:nil results:matches];
        if (matches.count > 0)
        {
			NSMutableArray *elements = [NSMutableArray new];
			for(SystemEventsUIElement *element in matches)
			{
				session.elementIndex++;
				NSString *myKey = [NSString stringWithFormat:@"%d", session.elementIndex];
				[session.elements setValue:element forKey:myKey];
				[elements addObject:[NSDictionary dictionaryWithObject:myKey forKey:@"ELEMENT"]];
			}
			return [self respondWithJson:elements status:0 session:sessionId];
        }
	}

	// TODO: add error handling
	// TODO: move element id code into session controller

    return [self respondWithJson:nil status:-1 session: sessionId];
}

// /session/:sessionId/element/active
// /session/:sessionId/element/:id

// POST /session/:sessionId/element/:id/element
-(AppiumMacHTTPJSONResponse*) postElementInElement:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSDictionary *postParams = [self dictionaryFromPostData:postData];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *rootElement = [session.elements objectForKey:elementId];
    NSString *using = (NSString*)[postParams objectForKey:@"using"];
    NSString *value = (NSString*)[postParams objectForKey:@"value"];

	AfMElementLocator *locator = [AfMElementLocator locatorWithSession:session using:using value:value];
	
	if (locator != nil)
	{
		SystemEventsUIElement *element = [locator findUsingBaseElement:rootElement];
        if (element != nil)
        {
            session.elementIndex++;
            NSString *myKey = [NSString stringWithFormat:@"%d", session.elementIndex];
            [session.elements setValue:element forKey:myKey];
            return [self respondWithJson:[NSDictionary dictionaryWithObject:myKey forKey:@"ELEMENT"] status:0 session:sessionId];
        }
	}

	// TODO: add error handling
	// TODO: move element id code into session controller

    return [self respondWithJson:nil status:-1 session: sessionId];
}

// POST /session/:sessionId/element/:id/elements
-(AppiumMacHTTPJSONResponse*) postElementsInElement:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSDictionary *postParams = [self dictionaryFromPostData:postData];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *rootElement = [session.elements objectForKey:elementId];
    NSString *using = (NSString*)[postParams objectForKey:@"using"];
    NSString *value = (NSString*)[postParams objectForKey:@"value"];

	AfMElementLocator *locator = [AfMElementLocator locatorWithSession:session using:using value:value];

	if (locator != nil)
	{
		NSMutableArray *matches = [NSMutableArray new];
		[locator findAllUsingBaseElement:rootElement results:matches];
        if (matches.count > 0)
        {
			NSMutableArray *elements = [NSMutableArray new];
			for(SystemEventsUIElement *element in matches)
			{
				session.elementIndex++;
				NSString *myKey = [NSString stringWithFormat:@"%d", session.elementIndex];
				[session.elements setValue:element forKey:myKey];
				[elements addObject:[NSDictionary dictionaryWithObject:myKey forKey:@"ELEMENT"]];
			}
			return [self respondWithJson:elements status:0 session:sessionId];
        }
	}

	// TODO: add error handling
	// TODO: move element id code into session controller

    return [self respondWithJson:nil status:-1 session: sessionId];
}


// POST /session/:sessionId/element/:id/click
-(AppiumMacHTTPJSONResponse*) postElementClick:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSString *elementId = [Utility getElementIDFromPath:path];

    SystemEventsUIElement *element = [session.elements objectForKey:elementId];
    if (element != nil)
    {
        [session clickElement:element];
    }
    // TODO: error handling
    return [self respondWithJson:nil status:0 session: sessionId];
}

// /session/:sessionId/element/:id/submit

// GET /session/:sessionId/element/:id/text
-(AppiumMacHTTPJSONResponse*) getElementText:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSString *elementId = [Utility getElementIDFromPath:path];

    SystemEventsUIElement *element = [session.elements objectForKey:elementId];
    if (element != nil)
    {
		SystemEventsAttribute *valueAttribute = (SystemEventsAttribute*)[element.attributes objectWithName:@"AXValue"];
		if (valueAttribute != nil)
		{
			NSString *text = [[valueAttribute value] get];
				return [self respondWithJson:text status:0 session: sessionId];
		}
    }

	// TODO: Add error handling

    return [self respondWithJson:nil status:0 session: sessionId];
}

// POST /session/:sessionId/element/:id/value
-(AppiumMacHTTPJSONResponse*) postElementValue:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSString *elementId = [Utility getElementIDFromPath:path];
    NSDictionary *postParams = [self dictionaryFromPostData:postData];

    NSArray *value = [postParams objectForKey:@"value"];
    [session sendKeys:[value componentsJoinedByString:@""] toElement:[session.elements objectForKey:elementId]];

    // TODO: add error handling
    // TODO: elements are session based

    return [self respondWithJson:nil status:0 session: sessionId];
}

// POST /session/:sessionId/keys
-(AppiumMacHTTPJSONResponse*) postKeys:(NSString*)path data:(NSData*)postData
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSDictionary *postParams = [self dictionaryFromPostData:postData];

    NSArray *value = [postParams objectForKey:@"value"];
    [session sendKeys:[value componentsJoinedByString:@""] toElement:nil];

    // TODO: add error handling
    // TODO: elements are session based

    return [self respondWithJson:nil status:0 session: sessionId];
}

// GET /session/:sessionId/element/:id/name
-(AppiumMacHTTPJSONResponse*) getElementName:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [session.elements objectForKey:elementId];
    if (element != nil)
    {
        return [self respondWithJson:element.name status:0 session: sessionId];
    }
    return [self respondWithJson:nil status:0 session: sessionId];
}

// POST /session/:sessionId/element/:id/clear
-(AppiumMacHTTPJSONResponse*) postElementClear:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [session.elements objectForKey:elementId];
    id value = [element value];
    if (value != nil && [value isKindOfClass:[NSString class]])
    {
        [element setValue:@""];
    }

    // TODO: Add error handling
    return [self respondWithJson:nil status:0 session: sessionId];
}

// GET /session/:sessionId/element/:id/selected
-(AppiumMacHTTPJSONResponse*) getElementIsSelected:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [session.elements objectForKey:elementId];
    if (element != nil)
    {
        return [self respondWithJson:[NSNumber numberWithBool:element.focused] status:0 session: sessionId];
    }
    return [self respondWithJson:nil status:0 session:sessionId];
}

// GET /session/:sessionId/element/:id/enabled
-(AppiumMacHTTPJSONResponse*) getElementIsEnabled:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [session.elements objectForKey:elementId];
    if (element != nil)
    {
        return [self respondWithJson:[NSNumber numberWithBool:element.enabled] status:0 session: sessionId];
    }
    return [self respondWithJson:nil status:0 session:sessionId];
}

// GET /session/:sessionId/element/:id/attribute/:name
-(AppiumMacHTTPJSONResponse*) getElementAttribute:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSString *elementId = [Utility getElementIDFromPath:path];
    NSString *attributeName = [Utility getItemFromPath:path withSeparator:@"/attribute/"];

    SystemEventsUIElement *element = [session.elements objectForKey:elementId];
    if (element != nil)
    {
		SystemEventsAttribute *attribute = (SystemEventsAttribute*)[element.attributes objectWithName:attributeName];
		if (attribute != nil)
		{
			NSString *text = [[attribute value] get];
			return [self respondWithJson:text status:0 session: sessionId];
		}
    }
    return [self respondWithJson:nil status:0 session:sessionId];
}

// GET /session/:sessionId/element/:id/equals/:other
-(AppiumMacHTTPJSONResponse*) getElementIsEqual:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSString *elementId = [Utility getElementIDFromPath:path];
    NSString *otherElementId = [Utility getItemFromPath:path withSeparator:@"/equals/"];
    SystemEventsUIElement *element = [session.elements objectForKey:elementId];
    SystemEventsUIElement *otherElement = [session.elements objectForKey:otherElementId];
    return [self respondWithJson:[NSNumber numberWithBool:[element isEqualTo:otherElement]] status:0 session:sessionId];
}

// /session/:sessionId/element/:id/displayed

// GET /session/:sessionId/element/:id/location
-(AppiumMacHTTPJSONResponse*) getElementLocation:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [session.elements objectForKey:elementId];
    if (element != nil)
    {
        return [self respondWithJson:element.position status:0 session: sessionId];
    }
    // TODO: Add error handling
    return [self respondWithJson:nil status:0 session:sessionId];
}

// /session/:sessionId/element/:id/location_in_view


// GET /session/:sessionId/element/:id/size
-(AppiumMacHTTPJSONResponse*) getElementSize:(NSString*)path
{
    NSString *sessionId = [Utility getSessionIDFromPath:path];
    AfMSessionController *session = [self controllerForSession:sessionId];
    NSString *elementId = [Utility getElementIDFromPath:path];
    SystemEventsUIElement *element = [session.elements objectForKey:elementId];
    if (element != nil)
    {
        return [self respondWithJson:element.size status:0 session: sessionId];
    }
    // TODO: Add error handling
    return [self respondWithJson:nil status:0 session:sessionId];
}

// /session/:sessionId/element/:id/css/:propertyName
// /session/:sessionId/orientation
// /session/:sessionId/alert_text
// /session/:sessionId/accept_alert
// /session/:sessionId/dismiss_alert
// /session/:sessionId/moveto
// /session/:sessionId/click
// /session/:sessionId/buttondown
// /session/:sessionId/buttonup
// /session/:sessionId/doubleclick
// /session/:sessionId/touch/click
// /session/:sessionId/touch/down
// /session/:sessionId/touch/up
// /session/:sessionId/touch/move
// /session/:sessionId/touch/scroll
// /session/:sessionId/touch/scroll
// /session/:sessionId/touch/doubleclick
// /session/:sessionId/touch/longclick
// /session/:sessionId/touch/flick
// /session/:sessionId/touch/flick
// /session/:sessionId/location
// /session/:sessionId/local_storage
// /session/:sessionId/local_storage/key/:key
// /session/:sessionId/local_storage/size
// /session/:sessionId/session_storage
// /session/:sessionId/session_storage/key/:key
// /session/:sessionId/session_storage/size
// /session/:sessionId/log
// /session/:sessionId/log/types
// /session/:sessionId/application_cache/status

@end