# SDL_GetWindowFromID

Get a window from a stored ID.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Window * SDL_GetWindowFromID(SDL_WindowID id);
```

</div>

## Function Parameters

|                                   |        |                       |
|-----------------------------------|--------|-----------------------|
| [SDL_WindowID](SDL_WindowID.html) | **id** | the ID of the window. |

## Return Value

([SDL_Window](SDL_Window.html) \*) Returns the window associated with
`id` or NULL if it doesn't exist; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The numeric ID is what [SDL_WindowEvent](SDL_WindowEvent.html)
references, and is necessary to map these events to specific
[SDL_Window](SDL_Window.html) objects.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetWindowID](SDL_GetWindowID.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
