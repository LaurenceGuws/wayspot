# SDL_CameraID

This is a unique ID for a camera device for the time it is connected to
the system, and is never reused for the lifetime of the application.

## Header File

Defined in
[\<SDL3/SDL_camera.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_camera.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef Uint32 SDL_CameraID;
```

</div>

## Remarks

If the device is disconnected and reconnected, it will get a new ID.

The value 0 is an invalid ID.

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_GetCameras](SDL_GetCameras.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryCamera](CategoryCamera.html)
