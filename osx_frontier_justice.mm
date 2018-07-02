#include <stdio.h>

#include <Cocoa/Cocoa.h>
#include <OpenGL/gl3.h>

@class WindowDelegate;
@interface WindowDelegate : NSView <NSWindowDelegate> {
@public
	NSRect windowRect;
}   
@end

@implementation WindowDelegate
-(void)windowWillClose:(NSNotification *)notification {
	[NSApp terminate:self];
}
@end

const char* vertexShaderSource = ""
"attribute vec3 position;"
"attribute vec3 color;"
"varying vec3 vertColor;"
"void main(){"
"   vertColor = color;"
"   gl_Position = vec4(position, 1);"
"}";

const char* fragmentShaderSource = ""
"varying vec3 vertColor;"
"void main(){"
"   gl_FragColor = vec4(vertColor, 1);"
"}";

int main(int argc, char** argv){
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init]; 
	[NSApplication sharedApplication]; 

	NSUInteger windowStyle = NSWindowStyleMaskTitled        | 
                             NSWindowStyleMaskClosable      | 
                             NSWindowStyleMaskResizable     | 
                             NSWindowStyleMaskMiniaturizable;

	NSRect screenRect = [[NSScreen mainScreen] frame];
	NSRect viewRect = NSMakeRect(0, 0, 800, 600); 
	NSRect windowRect = NSMakeRect(NSMidX(screenRect) - NSMidX(viewRect),
								 NSMidY(screenRect) - NSMidY(viewRect),
								 viewRect.size.width, 
								 viewRect.size.height);

	NSWindow * window = [[NSWindow alloc] initWithContentRect:windowRect 
						styleMask:windowStyle 
						backing:NSBackingStoreBuffered 
						defer:NO]; 
	[window autorelease]; 
 
	NSWindowController * windowController = [[NSWindowController alloc] initWithWindow:window]; 
	[windowController autorelease]; 

	// Since Snow Leopard, programs without application bundles and Info.plist files don't get a menubar 
	// and can't be brought to the front unless the presentation option is changed
	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
	
    int samples = 0;
	// Keep multisampling attributes at the start of the attribute lists since code below assumes they are array elements 0 through 4.
	NSOpenGLPixelFormatAttribute windowedAttrs[] = 
	{
		NSOpenGLPFAMultisample,
		NSOpenGLPFASampleBuffers, samples ? 1 : 0,
		NSOpenGLPFASamples, samples,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAColorSize, 32,
		NSOpenGLPFADepthSize, 24,
		NSOpenGLPFAAlphaSize, 8,
		NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy,
		0
	};

	// Try to choose a supported pixel format
	NSOpenGLPixelFormat* pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:windowedAttrs];

	if (!pf) {
		bool valid = false;
		while (!pf && samples > 0) {
			samples /= 2;
			windowedAttrs[2] = samples ? 1 : 0;
			windowedAttrs[4] = samples;
			pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:windowedAttrs];
			if (pf) {
				valid = true;
				break;
			}
		}
		
		if (!valid) {
			NSLog(@"OpenGL pixel format not supported.");
			return nil;
		}
	}
	
	NSOpenGLView *view = [[NSOpenGLView alloc] initWithFrame:windowRect pixelFormat:[pf autorelease]];

    [view prepareOpenGL];
		
	[[view window] setLevel: NSNormalWindowLevel];
	
	// Make all the OpenGL calls to setup rendering and build the necessary rendering objects
	[[view openGLContext] makeCurrentContext];
	// Synchronize buffer swaps with vertical refresh rate
	GLint swapInt = 1; // Vsynch on!
	[[view openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
	
	CGLContextObj cglContext = (CGLContextObj)[[view openGLContext] CGLContextObj];
	CGLPixelFormatObj cglPixelFormat = (CGLPixelFormatObj)[[view pixelFormat] CGLPixelFormatObj];
	
	GLint dim[2] = {windowRect.size.width, windowRect.size.height};
	CGLSetParameter(cglContext, kCGLCPSurfaceBackingSize, dim);
	CGLEnable(cglContext, kCGLCESurfaceBackingSize);
	
	CGLLockContext((CGLContextObj)[[view openGLContext] CGLContextObj]);
	NSLog(@"Initialize");

	NSLog(@"GL version:   %s", glGetString(GL_VERSION));
    NSLog(@"GLSL version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));
	// Temp
	glClearColor(0.5f, 0.6f, 0.7f, 1.0f);
	glViewport(0, 0, windowRect.size.width, windowRect.size.height);
	glEnable(GL_DEPTH_TEST);
	// End temp
	CGLUnlockContext((CGLContextObj)[[view openGLContext] CGLContextObj]); 

    [window setContentView:view];
    WindowDelegate *delegate = [WindowDelegate alloc];
    [delegate autorelease];
    [window setDelegate:delegate];
    [window setTitle:[[NSProcessInfo processInfo] processName]];
    [window setAcceptsMouseMovedEvents:YES];
    [window setCollectionBehavior: NSWindowCollectionBehaviorFullScreenPrimary];
	[window orderFrontRegardless];  
    [NSApp activateIgnoringOtherApps:YES];

    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL);
    glCompileShader(vertexShader);

    GLint success;
    GLchar infoLog[512];
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
        NSLog(@"ERROR::SHADER::VERTEX::COMPILATION_FAILED\n%s\n", infoLog);
    }

    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);

    glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
        NSLog(@"ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n%s\n", infoLog);
    }

    GLuint shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);

    glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    if (!success) {
        glGetProgramInfoLog(shaderProgram, 512, NULL, infoLog);
        NSLog(@"ERROR::SHADER::PROGRAM::LINKING_FAILED\n%s\n", infoLog);
    }
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    glUseProgram(shaderProgram);
    GLint positionId = glGetAttribLocation(shaderProgram, "position");
    GLint colorId = glGetAttribLocation(shaderProgram, "color");

    float vertices[] = {
        -1, -1, 0, 1, 0, 0,
        0, 1, 0, 0, 1, 0,
        1, -1, 0, 0, 0, 1
    };

    unsigned char elements[] = {0, 1, 2};

    GLuint vao, vbo, ebo;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glEnableVertexAttribArray(positionId);
    glVertexAttribPointer(positionId, 3, GL_FLOAT, GL_FALSE, sizeof(float) * 6, 0);
    glEnableVertexAttribArray(colorId);
    glVertexAttribPointer(colorId, 3, GL_FLOAT, GL_FALSE, sizeof(float) * 6, (void*)(sizeof(float) * 3));
    glGenBuffers(1, &ebo);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(elements), elements, GL_STATIC_DRAW);

    NSEvent* ev;  
    while(true){
        do {
            ev = [NSApp nextEventMatchingMask: NSEventMaskAny
                                    untilDate: nil
                                       inMode: NSDefaultRunLoopMode
                                      dequeue: YES];
            if (ev) {
                [NSApp sendEvent: ev];
                if([ev type] == NSEventTypeKeyDown){
                   switch([ev keyCode]){
                       case 53:{
                           [NSApp terminate:view];
                           break;
                       }
                       case 0:{
                           NSLog(@"A\n");
                           break;
                       }
                   }
                }
            }
        } while (ev);

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        glDrawElements(GL_TRIANGLES, 3, GL_UNSIGNED_BYTE, 0);

        CGLFlushDrawable((CGLContextObj)[[view openGLContext] CGLContextObj]);
    }

	[pool drain]; 
 
	return 0; 
}