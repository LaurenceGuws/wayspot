# SDL_GetCameraPosition

Get the position of the camera in relation to the system.

## Header File

Defined in
[\<SDL3/SDL_camera.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_camera.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_CameraPosition SDL_GetCameraPosition(SDL_CameraID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_CameraID](SDL_CameraID.html) | **instance_id** | the camera device instance ID. |

## Return Value

([SDL_CameraPosition](SDL_CameraPosition.html)) Returns the position of
the camera on the system hardware.

## Remarks

Most platforms will report UNKNOWN, but mobile devices, like phones, can
often make a distinction between cameras on the front of the device
(that points towards the user, for taking "selfies") and cameras on the
back (for filming in the direction the user is facing).

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
