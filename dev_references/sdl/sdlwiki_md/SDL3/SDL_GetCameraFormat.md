# SDL_GetCameraFormat

Get the spec that a camera is using when generating images.

## Header File

Defined in
[\<SDL3/SDL_camera.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_camera.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetCameraFormat(SDL_Camera *camera, SDL_CameraSpec *spec);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Camera](SDL_Camera.html) \* | **camera** | opened camera device. |
| [SDL_CameraSpec](SDL_CameraSpec.html) \* | **spec** | the [SDL_CameraSpec](SDL_CameraSpec.html) to be initialized by this function. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Note that this might not be the native format of the hardware, as SDL
might be converting to this format behind the scenes.

If the system is waiting for the user to approve access to the camera,
as some platforms require, this will return false, but this isn't
necessarily a fatal error; you should either wait for an
[SDL_EVENT_CAMERA_DEVICE_APPROVED](SDL_EVENT_CAMERA_DEVICE_APPROVED.html)
(or
[SDL_EVENT_CAMERA_DEVICE_DENIED](SDL_EVENT_CAMERA_DEVICE_DENIED.html))
event, or poll
[SDL_GetCameraPermissionState](SDL_GetCameraPermissionState.html)()
occasionally until it returns non-zero.

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
