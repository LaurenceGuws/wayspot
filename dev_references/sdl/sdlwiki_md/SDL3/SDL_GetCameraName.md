# SDL_GetCameraName

Get the human-readable device name for a camera.

## Header File

Defined in
[\<SDL3/SDL_camera.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_camera.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetCameraName(SDL_CameraID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_CameraID](SDL_CameraID.html) | **instance_id** | the camera device instance ID. |

## Return Value

(const char \*) Returns a human-readable device name or NULL on failure;
call [SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetCameras](SDL_GetCameras.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryCamera](CategoryCamera.html)
