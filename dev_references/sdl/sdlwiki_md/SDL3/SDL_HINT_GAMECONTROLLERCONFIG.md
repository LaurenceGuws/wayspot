# SDL_HINT_GAMECONTROLLERCONFIG

A variable that lets you manually hint extra gamecontroller db entries.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_GAMECONTROLLERCONFIG "SDL_GAMECONTROLLERCONFIG"
```

</div>

## Remarks

The variable should be newline delimited rows of gamecontroller config
data, see [SDL_gamepad](SDL_gamepad.html).h

You can update mappings after SDL is initialized with
[SDL_GetGamepadMappingForGUID](SDL_GetGamepadMappingForGUID.html)() and
[SDL_AddGamepadMapping](SDL_AddGamepadMapping.html)()

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
