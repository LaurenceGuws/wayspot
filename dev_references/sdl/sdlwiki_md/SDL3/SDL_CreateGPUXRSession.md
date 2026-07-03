# SDL_CreateGPUXRSession

Creates an OpenXR session.

## Header File

Defined in
[\<SDL3/SDL_openxr.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_openxr.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
XrResult SDL_CreateGPUXRSession(SDL_GPUDevice *device, const XrSessionCreateInfo *createinfo, XrSession *session);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| const XrSessionCreateInfo \* | **createinfo** | the create info for the OpenXR session, sans the system ID. |
| XrSession \* | **session** | a pointer filled in with an OpenXR session created for the given device. |

## Return Value

(XrResult) Returns the result of the call.

## Remarks

The OpenXR system ID is pulled from the passed GPU context.

## Version

This function is available since SDL 3.6.0.

## See Also

- [SDL_CreateGPUDeviceWithProperties](SDL_CreateGPUDeviceWithProperties.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryOpenxr](CategoryOpenxr.html)
