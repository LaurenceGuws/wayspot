# SDL_GetCameras

Get a list of currently connected camera devices.

## Header File

Defined in
[\<SDL3/SDL_camera.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_camera.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_CameraID * SDL_GetCameras(int *count);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| int \* | **count** | a pointer filled in with the number of cameras returned, may be NULL. |

## Return Value

([SDL_CameraID](SDL_CameraID.html) \*) Returns a 0 terminated array of
camera instance IDs or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information. This should be
freed with [SDL_free](SDL_free.html)() when it is no longer needed.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_OpenCamera](SDL_OpenCamera.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryCamera](CategoryCamera.html)
