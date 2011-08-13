#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

#import "EAGLView.h"
#import "WindowHandle.h"

#include "../../yg/screen.hpp"
#include "../../yg/texture.hpp"
#include "../../yg/resource_manager.hpp"
#include "../../yg/internal/opengl.hpp"
#include "../../yg/skin.hpp"
#include "IPhonePlatform.hpp"
#include "RenderBuffer.hpp"
#include "RenderContext.hpp"

@implementation EAGLView

@synthesize controller;
@synthesize windowHandle;
@synthesize renderContext;
@synthesize resourceManager;

// You must implement this method
+ (Class)layerClass
{
  return [CAEAGLLayer class];
}

// The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id)initWithCoder:(NSCoder*)coder
{
  if ((self = [super initWithCoder:coder]))
  {
    // Setup Layer Properties
    CAEAGLLayer * eaglLayer = (CAEAGLLayer *)self.layer;

    eaglLayer.opaque = YES;

    renderContext = shared_ptr<iphone::RenderContext>(new iphone::RenderContext());
    
    if (!renderContext.get())
    {
      [self release];
      return nil;
    }
    
    renderContext->makeCurrent();

    // to avoid grid bug on 3G device
    yg::RtFormat fmt = yg::Rt4Bpp;
    if ([[NSString stringWithFormat:@"%s", glGetString(GL_RENDERER)] hasPrefix:@"PowerVR MBX"])
      fmt = yg::Rt8Bpp;
    
    /// ColorFormat : RGB565
    /// Backbuffer : YES, (to prevent from loosing content when mixing with ordinary layers).
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithBool:NO],
                                    kEAGLDrawablePropertyRetainedBacking,
                                    kEAGLColorFormatRGB565,
                                    kEAGLDrawablePropertyColorFormat,
                                    nil];

    int etalonW = 320;
    int scrW = etalonW;

    UIDevice * device = [UIDevice currentDevice];

    float ver = [device.systemVersion floatValue];
    NSLog(@"%@", device.systemVersion);
    /// rounding problems
    if (ver >= 3.199)
    {
      UIScreen * mainScr = [UIScreen mainScreen];
      scrW = mainScr.currentMode.size.width;
      if (scrW == 640)
        self.contentScaleFactor = 2.0;
    }

    frameBuffer = shared_ptr<yg::gl::FrameBuffer>(new yg::gl::FrameBuffer());

    int bigVBSize = pow(2, ceil(log2(15000 * sizeof(yg::gl::Vertex))));
    int bigIBSize = pow(2, ceil(log2(30000 * sizeof(unsigned short))));

    int smallVBSize = pow(2, ceil(log2(1500 * sizeof(yg::gl::Vertex))));
    int smallIBSize = pow(2, ceil(log2(3000 * sizeof(unsigned short))));
    
    int blitVBSize = pow(2, ceil(log2(10 * sizeof(yg::gl::AuxVertex))));
    int blitIBSize = pow(2, ceil(log2(10 * sizeof(unsigned short))));

    NSLog(@"Vendor: %s, Renderer: %s", glGetString(GL_VENDOR), glGetString(GL_RENDERER));
    
    Platform & pl = GetPlatform();
    
    resourceManager = shared_ptr<yg::ResourceManager>(new yg::ResourceManager(
          bigVBSize, bigIBSize, 6 * GetPlatform().CpuCores(),
          smallVBSize, smallIBSize, 15 * GetPlatform().CpuCores(),
          blitVBSize, blitIBSize, 15 * GetPlatform().CpuCores(),
          512, 256, 10 * GetPlatform().CpuCores(),
          512, 256, 10 * GetPlatform().CpuCores(),
          GetPlatform().TileSize(),
          GetPlatform().TileSize(),
          GetPlatform().MaxTilesCount(),
					"unicode_blocks.txt",
					"fonts_whitelist.txt",
 					"fonts_blacklist.txt",
          1.5 * 1024 * 1024,
          GetPlatform().CpuCores() + 1,
          fmt,
          !yg::gl::g_isBufferObjectsSupported));
    
    Platform::FilesList fonts;
    pl.GetFontNames(fonts);
		resourceManager->addFonts(fonts);

		DrawerYG::params_t p;
		p.m_resourceManager = resourceManager;
    p.m_frameBuffer = frameBuffer;
    p.m_glyphCacheID = resourceManager->guiThreadGlyphCacheID();

		drawer = shared_ptr<DrawerYG>(new DrawerYG(pl.SkinName(), p));

//		frameBuffer->onSize(renderBuffer->width(), renderBuffer->height());
//		frameBuffer->setRenderTarget(renderBuffer);

		windowHandle = shared_ptr<iphone::WindowHandle>(new iphone::WindowHandle(self));
		windowHandle->setDrawer(drawer);
		windowHandle->setRenderContext(renderContext);
  }

  return self;
}

- (void)onSize:(int)width withHeight:(int)height
{
	/// free old video memory
	frameBuffer->resetRenderTarget();
	renderBuffer.reset();

	/// allocate the new one
	renderBuffer = shared_ptr<iphone::RenderBuffer>(new iphone::RenderBuffer(renderContext, (CAEAGLLayer*)self.layer));
	frameBuffer->setRenderTarget(renderBuffer);
	frameBuffer->onSize(width, height);
	drawer->onSize(width, height);

  
  drawer->screen()->beginFrame();
  drawer->screen()->clear();
  drawer->screen()->endFrame();
}

- (void)drawView
{
	[controller onPaint];
	renderBuffer->present();
}

- (void)drawViewThunk:(id)obj
{
	[self drawView];
}

- (void)drawViewOnMainThread
{
	[self performSelectorOnMainThread:@selector(drawViewThunk:) withObject:nil waitUntilDone:NO];
}

- (void)layoutSubviews
{
  CGFloat const scale = self.contentScaleFactor;
  CGSize const s = self.frame.size;
	[self.controller onResize:s.width * scale withHeight:s.height * scale];
	[self onSize:s.width * scale withHeight:s.height * scale];
}

- (void)dealloc
{
  [EAGLContext setCurrentContext:nil];
  [super dealloc];
}


@end
