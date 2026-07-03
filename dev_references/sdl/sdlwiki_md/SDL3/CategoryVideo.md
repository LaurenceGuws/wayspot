# CategoryVideo

SDL's video subsystem is largely interested in abstracting window
management from the underlying operating system. You can create windows,
manage them in various ways, set them fullscreen, and get events when
interesting things happen with them, such as the mouse or keyboard
interacting with a window.

The video subsystem is also interested in abstracting away some
platform-specific differences in OpenGL: context creation, swapping
buffers, etc. This may be crucial to your app, but also you are not
required to use OpenGL at all. In fact, SDL can provide rendering to
those windows as well, either with an easy-to-use [2D
API](CategoryRender.html) or with a more-powerful [GPU
API](CategoryGPU.html) . Of course, it can simply get out of your way
and give you the window handles you need to use Vulkan, Direct3D, Metal,
or whatever else you like directly, too.

The video subsystem covers a lot of functionality, out of necessity, so
it is worth perusing the list of functions just to see what's available,
but most apps can get by with simply creating a window and listening for
events, so start with [SDL_CreateWindow](SDL_CreateWindow.html)() and
[SDL_PollEvent](SDL_PollEvent.html)().

## Functions

- [SDL_CreatePopupWindow](SDL_CreatePopupWindow.html)
- [SDL_CreateWindow](SDL_CreateWindow.html)
- [SDL_CreateWindowWithProperties](SDL_CreateWindowWithProperties.html)
- [SDL_DestroyWindow](SDL_DestroyWindow.html)
- [SDL_DestroyWindowSurface](SDL_DestroyWindowSurface.html)
- [SDL_DisableScreenSaver](SDL_DisableScreenSaver.html)
- [SDL_EGL_GetCurrentConfig](SDL_EGL_GetCurrentConfig.html)
- [SDL_EGL_GetCurrentDisplay](SDL_EGL_GetCurrentDisplay.html)
- [SDL_EGL_GetProcAddress](SDL_EGL_GetProcAddress.html)
- [SDL_EGL_GetWindowSurface](SDL_EGL_GetWindowSurface.html)
- [SDL_EGL_SetAttributeCallbacks](SDL_EGL_SetAttributeCallbacks.html)
- [SDL_EnableScreenSaver](SDL_EnableScreenSaver.html)
- [SDL_FlashWindow](SDL_FlashWindow.html)
- [SDL_GetClosestFullscreenDisplayMode](SDL_GetClosestFullscreenDisplayMode.html)
- [SDL_GetCurrentDisplayMode](SDL_GetCurrentDisplayMode.html)
- [SDL_GetCurrentDisplayOrientation](SDL_GetCurrentDisplayOrientation.html)
- [SDL_GetCurrentVideoDriver](SDL_GetCurrentVideoDriver.html)
- [SDL_GetDesktopDisplayMode](SDL_GetDesktopDisplayMode.html)
- [SDL_GetDisplayBounds](SDL_GetDisplayBounds.html)
- [SDL_GetDisplayContentScale](SDL_GetDisplayContentScale.html)
- [SDL_GetDisplayForPoint](SDL_GetDisplayForPoint.html)
- [SDL_GetDisplayForRect](SDL_GetDisplayForRect.html)
- [SDL_GetDisplayForWindow](SDL_GetDisplayForWindow.html)
- [SDL_GetDisplayName](SDL_GetDisplayName.html)
- [SDL_GetDisplayProperties](SDL_GetDisplayProperties.html)
- [SDL_GetDisplays](SDL_GetDisplays.html)
- [SDL_GetDisplayUsableBounds](SDL_GetDisplayUsableBounds.html)
- [SDL_GetFullscreenDisplayModes](SDL_GetFullscreenDisplayModes.html)
- [SDL_GetGrabbedWindow](SDL_GetGrabbedWindow.html)
- [SDL_GetNaturalDisplayOrientation](SDL_GetNaturalDisplayOrientation.html)
- [SDL_GetNumVideoDrivers](SDL_GetNumVideoDrivers.html)
- [SDL_GetPrimaryDisplay](SDL_GetPrimaryDisplay.html)
- [SDL_GetSystemTheme](SDL_GetSystemTheme.html)
- [SDL_GetVideoDriver](SDL_GetVideoDriver.html)
- [SDL_GetWindowAspectRatio](SDL_GetWindowAspectRatio.html)
- [SDL_GetWindowBordersSize](SDL_GetWindowBordersSize.html)
- [SDL_GetWindowDisplayScale](SDL_GetWindowDisplayScale.html)
- [SDL_GetWindowFlags](SDL_GetWindowFlags.html)
- [SDL_GetWindowFromID](SDL_GetWindowFromID.html)
- [SDL_GetWindowFullscreenMode](SDL_GetWindowFullscreenMode.html)
- [SDL_GetWindowICCProfile](SDL_GetWindowICCProfile.html)
- [SDL_GetWindowID](SDL_GetWindowID.html)
- [SDL_GetWindowKeyboardGrab](SDL_GetWindowKeyboardGrab.html)
- [SDL_GetWindowMaximumSize](SDL_GetWindowMaximumSize.html)
- [SDL_GetWindowMinimumSize](SDL_GetWindowMinimumSize.html)
- [SDL_GetWindowMouseGrab](SDL_GetWindowMouseGrab.html)
- [SDL_GetWindowMouseRect](SDL_GetWindowMouseRect.html)
- [SDL_GetWindowOpacity](SDL_GetWindowOpacity.html)
- [SDL_GetWindowParent](SDL_GetWindowParent.html)
- [SDL_GetWindowPixelDensity](SDL_GetWindowPixelDensity.html)
- [SDL_GetWindowPixelFormat](SDL_GetWindowPixelFormat.html)
- [SDL_GetWindowPosition](SDL_GetWindowPosition.html)
- [SDL_GetWindowProgressState](SDL_GetWindowProgressState.html)
- [SDL_GetWindowProgressValue](SDL_GetWindowProgressValue.html)
- [SDL_GetWindowProperties](SDL_GetWindowProperties.html)
- [SDL_GetWindows](SDL_GetWindows.html)
- [SDL_GetWindowSafeArea](SDL_GetWindowSafeArea.html)
- [SDL_GetWindowSize](SDL_GetWindowSize.html)
- [SDL_GetWindowSizeInPixels](SDL_GetWindowSizeInPixels.html)
- [SDL_GetWindowSurface](SDL_GetWindowSurface.html)
- [SDL_GetWindowSurfaceVSync](SDL_GetWindowSurfaceVSync.html)
- [SDL_GetWindowTitle](SDL_GetWindowTitle.html)
- [SDL_GL_CreateContext](SDL_GL_CreateContext.html)
- [SDL_GL_DestroyContext](SDL_GL_DestroyContext.html)
- [SDL_GL_ExtensionSupported](SDL_GL_ExtensionSupported.html)
- [SDL_GL_GetAttribute](SDL_GL_GetAttribute.html)
- [SDL_GL_GetCurrentContext](SDL_GL_GetCurrentContext.html)
- [SDL_GL_GetCurrentWindow](SDL_GL_GetCurrentWindow.html)
- [SDL_GL_GetProcAddress](SDL_GL_GetProcAddress.html)
- [SDL_GL_GetSwapInterval](SDL_GL_GetSwapInterval.html)
- [SDL_GL_LoadLibrary](SDL_GL_LoadLibrary.html)
- [SDL_GL_MakeCurrent](SDL_GL_MakeCurrent.html)
- [SDL_GL_ResetAttributes](SDL_GL_ResetAttributes.html)
- [SDL_GL_SetAttribute](SDL_GL_SetAttribute.html)
- [SDL_GL_SetSwapInterval](SDL_GL_SetSwapInterval.html)
- [SDL_GL_SwapWindow](SDL_GL_SwapWindow.html)
- [SDL_GL_UnloadLibrary](SDL_GL_UnloadLibrary.html)
- [SDL_HideWindow](SDL_HideWindow.html)
- [SDL_MaximizeWindow](SDL_MaximizeWindow.html)
- [SDL_MinimizeWindow](SDL_MinimizeWindow.html)
- [SDL_RaiseWindow](SDL_RaiseWindow.html)
- [SDL_RestoreWindow](SDL_RestoreWindow.html)
- [SDL_ScreenSaverEnabled](SDL_ScreenSaverEnabled.html)
- [SDL_SetWindowAlwaysOnTop](SDL_SetWindowAlwaysOnTop.html)
- [SDL_SetWindowAspectRatio](SDL_SetWindowAspectRatio.html)
- [SDL_SetWindowBordered](SDL_SetWindowBordered.html)
- [SDL_SetWindowFillDocument](SDL_SetWindowFillDocument.html)
- [SDL_SetWindowFocusable](SDL_SetWindowFocusable.html)
- [SDL_SetWindowFullscreen](SDL_SetWindowFullscreen.html)
- [SDL_SetWindowFullscreenMode](SDL_SetWindowFullscreenMode.html)
- [SDL_SetWindowHitTest](SDL_SetWindowHitTest.html)
- [SDL_SetWindowIcon](SDL_SetWindowIcon.html)
- [SDL_SetWindowKeyboardGrab](SDL_SetWindowKeyboardGrab.html)
- [SDL_SetWindowMaximumSize](SDL_SetWindowMaximumSize.html)
- [SDL_SetWindowMinimumSize](SDL_SetWindowMinimumSize.html)
- [SDL_SetWindowModal](SDL_SetWindowModal.html)
- [SDL_SetWindowMouseGrab](SDL_SetWindowMouseGrab.html)
- [SDL_SetWindowMouseRect](SDL_SetWindowMouseRect.html)
- [SDL_SetWindowOpacity](SDL_SetWindowOpacity.html)
- [SDL_SetWindowParent](SDL_SetWindowParent.html)
- [SDL_SetWindowPosition](SDL_SetWindowPosition.html)
- [SDL_SetWindowProgressState](SDL_SetWindowProgressState.html)
- [SDL_SetWindowProgressValue](SDL_SetWindowProgressValue.html)
- [SDL_SetWindowResizable](SDL_SetWindowResizable.html)
- [SDL_SetWindowShape](SDL_SetWindowShape.html)
- [SDL_SetWindowSize](SDL_SetWindowSize.html)
- [SDL_SetWindowSurfaceVSync](SDL_SetWindowSurfaceVSync.html)
- [SDL_SetWindowTitle](SDL_SetWindowTitle.html)
- [SDL_ShowWindow](SDL_ShowWindow.html)
- [SDL_ShowWindowSystemMenu](SDL_ShowWindowSystemMenu.html)
- [SDL_SyncWindow](SDL_SyncWindow.html)
- [SDL_UpdateWindowSurface](SDL_UpdateWindowSurface.html)
- [SDL_UpdateWindowSurfaceRects](SDL_UpdateWindowSurfaceRects.html)
- [SDL_WindowHasSurface](SDL_WindowHasSurface.html)

## Datatypes

- [SDL_DisplayID](SDL_DisplayID.html)
- [SDL_DisplayModeData](SDL_DisplayModeData.html)
- [SDL_EGLAttrib](SDL_EGLAttrib.html)
- [SDL_EGLAttribArrayCallback](SDL_EGLAttribArrayCallback.html)
- [SDL_EGLConfig](SDL_EGLConfig.html)
- [SDL_EGLDisplay](SDL_EGLDisplay.html)
- [SDL_EGLint](SDL_EGLint.html)
- [SDL_EGLIntArrayCallback](SDL_EGLIntArrayCallback.html)
- [SDL_EGLSurface](SDL_EGLSurface.html)
- [SDL_GLContext](SDL_GLContext.html)
- [SDL_GLContextFlag](SDL_GLContextFlag.html)
- [SDL_GLContextReleaseFlag](SDL_GLContextReleaseFlag.html)
- [SDL_GLContextResetNotification](SDL_GLContextResetNotification.html)
- [SDL_GLProfile](SDL_GLProfile.html)
- [SDL_HitTest](SDL_HitTest.html)
- [SDL_Window](SDL_Window.html)
- [SDL_WindowFlags](SDL_WindowFlags.html)
- [SDL_WindowID](SDL_WindowID.html)

## Structs

- [SDL_DisplayMode](SDL_DisplayMode.html)

## Enums

- [SDL_DisplayOrientation](SDL_DisplayOrientation.html)
- [SDL_FlashOperation](SDL_FlashOperation.html)
- [SDL_GLAttr](SDL_GLAttr.html)
- [SDL_HitTestResult](SDL_HitTestResult.html)
- [SDL_ProgressState](SDL_ProgressState.html)
- [SDL_SystemTheme](SDL_SystemTheme.html)

## Macros

- [SDL_PROP_GLOBAL_VIDEO_WAYLAND_WL_DISPLAY_POINTER](SDL_PROP_GLOBAL_VIDEO_WAYLAND_WL_DISPLAY_POINTER.html)
- [SDL_WINDOWPOS_CENTERED](SDL_WINDOWPOS_CENTERED.html)
- [SDL_WINDOWPOS_CENTERED_DISPLAY](SDL_WINDOWPOS_CENTERED_DISPLAY.html)
- [SDL_WINDOWPOS_CENTERED_MASK](SDL_WINDOWPOS_CENTERED_MASK.html)
- [SDL_WINDOWPOS_ISCENTERED](SDL_WINDOWPOS_ISCENTERED.html)
- [SDL_WINDOWPOS_ISUNDEFINED](SDL_WINDOWPOS_ISUNDEFINED.html)
- [SDL_WINDOWPOS_UNDEFINED](SDL_WINDOWPOS_UNDEFINED.html)
- [SDL_WINDOWPOS_UNDEFINED_DISPLAY](SDL_WINDOWPOS_UNDEFINED_DISPLAY.html)
- [SDL_WINDOWPOS_UNDEFINED_MASK](SDL_WINDOWPOS_UNDEFINED_MASK.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
