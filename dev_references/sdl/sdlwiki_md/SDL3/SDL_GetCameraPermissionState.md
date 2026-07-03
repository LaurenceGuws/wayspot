# SDL_GetCameraPermissionState

Query if camera access has been approved by the user.

## Header File

Defined in
[\<SDL3/SDL_camera.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_camera.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_CameraPermissionState SDL_GetCameraPermissionState(SDL_Camera *camera);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Camera](SDL_Camera.html) \* | **camera** | the opened camera device to query. |

## Return Value

([SDL_CameraPermissionState](SDL_CameraPermissionState.html)) Returns an
[SDL_CameraPermissionState](SDL_CameraPermissionState.html) value
indicating if access is granted, or
[`SDL_CAMERA_PERMISSION_STATE_PENDING`](SDL_CAMERA_PERMISSION_STATE_PENDING.html)
if the decision is still pending.

## Remarks

Cameras will not function between when the device is opened by the app
and when the user permits access to the hardware. On some platforms,
this presents as a popup dialog where the user has to explicitly approve
access; on others the approval might be implicit and not alert the user
at all.

This function can be used to check the status of that approval. It will
return
[SDL_CAMERA_PERMISSION_STATE_PENDING](SDL_CAMERA_PERMISSION_STATE_PENDING.html)
if waiting for user response,
[SDL_CAMERA_PERMISSION_STATE_APPROVED](SDL_CAMERA_PERMISSION_STATE_APPROVED.html)
if the camera is approved for use, and
[SDL_CAMERA_PERMISSION_STATE_DENIED](SDL_CAMERA_PERMISSION_STATE_DENIED.html)
if the user denied access.

Instead of polling with this function, you can wait for a
[SDL_EVENT_CAMERA_DEVICE_APPROVED](SDL_EVENT_CAMERA_DEVICE_APPROVED.html)
(or
[SDL_EVENT_CAMERA_DEVICE_DENIED](SDL_EVENT_CAMERA_DEVICE_DENIED.html))
event in the standard SDL event loop, which is guaranteed to be sent
once when permission to use the camera is decided.

If a camera is declined, there's nothing to be done but call
[SDL_CloseCamera](SDL_CloseCamera.html)() to dispose of it.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_OpenCamera](SDL_OpenCamera.html)
- [SDL_CloseCamera](SDL_CloseCamera.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryCamera](CategoryCamera.html)
