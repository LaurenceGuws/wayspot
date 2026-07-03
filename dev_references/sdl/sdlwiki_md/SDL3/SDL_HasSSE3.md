# SDL_HasSSE3

Determine whether the CPU has SSE3 features.

## Header File

Defined in
[\<SDL3/SDL_cpuinfo.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_cpuinfo.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_HasSSE3(void);
```

</div>

## Return Value

(bool) Returns true if the CPU has SSE3 features or false if not.

## Remarks

This always returns false on CPUs that aren't using Intel instruction
sets.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_HasSSE](SDL_HasSSE.html)
- [SDL_HasSSE2](SDL_HasSSE2.html)
- [SDL_HasSSE41](SDL_HasSSE41.html)
- [SDL_HasSSE42](SDL_HasSSE42.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryCPUInfo](CategoryCPUInfo.html)
