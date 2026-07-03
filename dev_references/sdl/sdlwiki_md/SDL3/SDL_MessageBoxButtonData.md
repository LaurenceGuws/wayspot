# SDL_MessageBoxButtonData

Individual button data.

## Header File

Defined in
[\<SDL3/SDL_messagebox.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_messagebox.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_MessageBoxButtonData
{
    SDL_MessageBoxButtonFlags flags;
    int buttonID;       /**< User defined button id (value returned via SDL_ShowMessageBox) */
    const char *text;   /**< The UTF-8 button text */
} SDL_MessageBoxButtonData;
```

</div>

## Version

This struct is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryMessagebox](CategoryMessagebox.html)
