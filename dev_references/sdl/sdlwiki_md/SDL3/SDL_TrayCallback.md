# SDL_TrayCallback

A callback that is invoked when a tray entry is selected.

## Header File

Defined in
[\<SDL3/SDL_tray.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_tray.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef void (SDLCALL *SDL_TrayCallback)(void *userdata, SDL_TrayEntry *entry);
```

</div>

## Function Parameters

|  |  |
|----|----|
| **userdata** | an optional pointer to pass extra data to the callback when it will be invoked. |
| **entry** | the tray entry that was selected. |

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_SetTrayEntryCallback](SDL_SetTrayEntryCallback.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryTray](CategoryTray.html)
