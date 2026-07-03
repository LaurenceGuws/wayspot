# SDL_GL_LoadLibrary

Dynamically load an OpenGL library.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GL_LoadLibrary(const char *path);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **path** | the platform dependent OpenGL library name, or NULL to open the default OpenGL library. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This should be done after initializing the video driver, but before
creating any OpenGL windows. If no OpenGL library is loaded, the default
library will be loaded upon creation of the first OpenGL window.

If you do this, you need to retrieve all of the GL functions used in
your program from the dynamic library using
[SDL_GL_GetProcAddress](SDL_GL_GetProcAddress.html)().

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GL_GetProcAddress](SDL_GL_GetProcAddress.html)
- [SDL_GL_UnloadLibrary](SDL_GL_UnloadLibrary.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
