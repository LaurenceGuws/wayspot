# CategoryCamera

Video capture for the SDL library.

This API lets apps read input from video sources, like webcams. Camera
devices can be enumerated, queried, and opened. Once opened, it will
provide [SDL_Surface](SDL_Surface.html) objects as new frames of video
come in. These surfaces can be uploaded to an
[SDL_Texture](SDL_Texture.html) or processed as pixels in memory.

Several platforms will alert the user if an app tries to access a
camera, and some will present a UI asking the user if your application
should be allowed to obtain images at all, which they can deny. A
successfully opened camera will not provide images until permission is
granted. Applications, after opening a camera device, can see if they
were granted access by either polling with the
[SDL_GetCameraPermissionState](SDL_GetCameraPermissionState.html)()
function, or waiting for an
[SDL_EVENT_CAMERA_DEVICE_APPROVED](SDL_EVENT_CAMERA_DEVICE_APPROVED.html)
or [SDL_EVENT_CAMERA_DEVICE_DENIED](SDL_EVENT_CAMERA_DEVICE_DENIED.html)
event. Platforms that don't have any user approval process will report
approval immediately.

Note that SDL cameras only provide video as individual frames; they will
not provide full-motion video encoded in a movie file format, although
an app is free to encode the acquired frames into any format it likes.
It also does not provide audio from the camera hardware through this
API; not only do many webcams not have microphones at all, many
people--from streamers to people on Zoom calls--will want to use a
separate microphone regardless of the camera. In any case, recorded
audio will be available through SDL's audio API no matter what hardware
provides the microphone.

## Camera gotchas

Consumer-level camera hardware tends to take a little while to warm up,
once the device has been opened. Generally most camera apps have some
sort of UI to take a picture (a button to snap a pic while a preview is
showing, some sort of multi-second countdown for the user to pose, like
a photo booth), which puts control in the users' hands, or they are
intended to stay on for long times (Pokemon Go, etc).

It's not uncommon that a newly-opened camera will provide a couple of
completely black frames, maybe followed by some under-exposed images. If
taking a single frame automatically, or recording video from a camera's
input without the user initiating it from a preview, it could be wise to
drop the first several frames (if not the first several *seconds* worth
of frames!) before using images from a camera.

## Functions

- [SDL_AcquireCameraFrame](SDL_AcquireCameraFrame.html)
- [SDL_CloseCamera](SDL_CloseCamera.html)
- [SDL_GetCameraDriver](SDL_GetCameraDriver.html)
- [SDL_GetCameraFormat](SDL_GetCameraFormat.html)
- [SDL_GetCameraID](SDL_GetCameraID.html)
- [SDL_GetCameraName](SDL_GetCameraName.html)
- [SDL_GetCameraPermissionState](SDL_GetCameraPermissionState.html)
- [SDL_GetCameraPosition](SDL_GetCameraPosition.html)
- [SDL_GetCameraProperties](SDL_GetCameraProperties.html)
- [SDL_GetCameras](SDL_GetCameras.html)
- [SDL_GetCameraSupportedFormats](SDL_GetCameraSupportedFormats.html)
- [SDL_GetCurrentCameraDriver](SDL_GetCurrentCameraDriver.html)
- [SDL_GetNumCameraDrivers](SDL_GetNumCameraDrivers.html)
- [SDL_OpenCamera](SDL_OpenCamera.html)
- [SDL_ReleaseCameraFrame](SDL_ReleaseCameraFrame.html)

## Datatypes

- [SDL_Camera](SDL_Camera.html)
- [SDL_CameraID](SDL_CameraID.html)

## Structs

- [SDL_CameraSpec](SDL_CameraSpec.html)

## Enums

- [SDL_CameraPermissionState](SDL_CameraPermissionState.html)
- [SDL_CameraPosition](SDL_CameraPosition.html)

## Macros

- (none.)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
