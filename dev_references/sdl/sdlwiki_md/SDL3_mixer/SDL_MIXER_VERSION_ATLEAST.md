###### (This function is part of SDL_mixer, a separate library from SDL.)

# SDL_MIXER_VERSION_ATLEAST

This macro will evaluate to true if compiled with SDL_mixer at least
X.Y.Z.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_MIXER_VERSION_ATLEAST(X, Y, Z) \
    ((SDL_MIXER_MAJOR_VERSION >= X) && \
     (SDL_MIXER_MAJOR_VERSION > X || SDL_MIXER_MINOR_VERSION >= Y) && \
     (SDL_MIXER_MAJOR_VERSION > X || SDL_MIXER_MINOR_VERSION > Y || SDL_MIXER_MICRO_VERSION >= Z))
```

</div>

## Version

This macro is available since SDL_mixer 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategorySDLMixer](CategorySDLMixer.html)
