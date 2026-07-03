# SDL_GetCameraID

Get the instance ID of an opened camera.

## Header File

Defined in
[\<SDL3/SDL_camera.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_camera.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_CameraID SDL_GetCameraID(SDL_Camera *camera);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Camera](SDL_Camera.html) \* | **camera** | an [SDL_Camera](SDL_Camera.html) to query. |

## Return Value

([SDL_CameraID](SDL_CameraID.html)) Returns the instance ID of the
specified camera on success or 0 on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

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
