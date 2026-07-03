# SDL_CloseCamera

Use this function to shut down camera processing and close the camera
device.

## Header File

Defined in
[\<SDL3/SDL_camera.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_camera.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_CloseCamera(SDL_Camera *camera);
```

</div>

## Function Parameters

|                                  |            |                       |
|----------------------------------|------------|-----------------------|
| [SDL_Camera](SDL_Camera.html) \* | **camera** | opened camera device. |

## Thread Safety

It is safe to call this function from any thread, but no thread may
reference `device` once this function is called.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_OpenCamera](SDL_OpenCamera.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryCamera](CategoryCamera.html)
