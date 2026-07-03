# CategoryCPUInfo

CPU feature detection for SDL.

These functions are largely concerned with reporting if the system has
access to various SIMD instruction sets, but also has other important
info to share, such as system RAM size and number of logical CPU cores.

CPU instruction set checks, like [SDL_HasSSE](SDL_HasSSE.html)() and
[SDL_HasNEON](SDL_HasNEON.html)(), are available on all platforms, even
if they don't make sense (an ARM processor will never have SSE and an
x86 processor will never have NEON, for example, but these functions
still exist and will simply return false in these cases).

## Functions

- [SDL_GetCPUCacheLineSize](SDL_GetCPUCacheLineSize.html)
- [SDL_GetNumLogicalCPUCores](SDL_GetNumLogicalCPUCores.html)
- [SDL_GetSIMDAlignment](SDL_GetSIMDAlignment.html)
- [SDL_GetSystemPageSize](SDL_GetSystemPageSize.html)
- [SDL_GetSystemRAM](SDL_GetSystemRAM.html)
- [SDL_HasAltiVec](SDL_HasAltiVec.html)
- [SDL_HasARMSIMD](SDL_HasARMSIMD.html)
- [SDL_HasAVX](SDL_HasAVX.html)
- [SDL_HasAVX2](SDL_HasAVX2.html)
- [SDL_HasAVX512F](SDL_HasAVX512F.html)
- [SDL_HasLASX](SDL_HasLASX.html)
- [SDL_HasLSX](SDL_HasLSX.html)
- [SDL_HasMMX](SDL_HasMMX.html)
- [SDL_HasNEON](SDL_HasNEON.html)
- [SDL_HasSSE](SDL_HasSSE.html)
- [SDL_HasSSE2](SDL_HasSSE2.html)
- [SDL_HasSSE3](SDL_HasSSE3.html)
- [SDL_HasSSE41](SDL_HasSSE41.html)
- [SDL_HasSSE42](SDL_HasSSE42.html)

## Datatypes

- (none.)

## Structs

- (none.)

## Enums

- (none.)

## Macros

- [SDL_CACHELINE_SIZE](SDL_CACHELINE_SIZE.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
