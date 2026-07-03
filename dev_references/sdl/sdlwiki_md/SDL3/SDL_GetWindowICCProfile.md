# SDL_GetWindowICCProfile

Get the raw ICC profile data for the screen the window is currently on.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void * SDL_GetWindowICCProfile(SDL_Window *window, size_t *size);
```

</div>

## Function Parameters

|                                  |            |                              |
|----------------------------------|------------|------------------------------|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to query.         |
| size_t \*                        | **size**   | the size of the ICC profile. |

## Return Value

(void \*) Returns the raw ICC profile data on success or NULL on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.
This should be freed with [SDL_free](SDL_free.html)() when it is no
longer needed.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
