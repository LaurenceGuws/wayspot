# SDL_RequestAndroidPermissionCallback

Callback that presents a response from a
[SDL_RequestAndroidPermission](SDL_RequestAndroidPermission.html) call.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef void (SDLCALL *SDL_RequestAndroidPermissionCallback)(void *userdata, const char *permission, bool granted);
```

</div>

## Function Parameters

|                |                                                           |
|----------------|-----------------------------------------------------------|
| **userdata**   | an app-controlled pointer that is passed to the callback. |
| **permission** | the Android-specific permission name that was requested.  |
| **granted**    | true if permission is granted, false if denied.           |

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_RequestAndroidPermission](SDL_RequestAndroidPermission.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategorySystem](CategorySystem.html)
