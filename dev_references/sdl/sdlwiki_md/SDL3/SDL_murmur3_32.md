# SDL_murmur3_32

Calculate a 32-bit MurmurHash3 value for a block of data.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Uint32 SDL_murmur3_32(const void *data, size_t len, Uint32 seed);
```

</div>

## Function Parameters

|                       |          |                                           |
|-----------------------|----------|-------------------------------------------|
| const void \*         | **data** | the data to be hashed.                    |
| size_t                | **len**  | the size of data, in bytes.               |
| [Uint32](Uint32.html) | **seed** | a value that alters the final hash value. |

## Return Value

([Uint32](Uint32.html)) Returns a Murmur3 32-bit hash value.

## Remarks

<https://en.wikipedia.org/wiki/MurmurHash>

A seed may be specified, which changes the final results consistently,
but this does not work like [SDL_crc16](SDL_crc16.html) and
[SDL_crc32](SDL_crc32.html): you can't feed a previous result from this
function back into itself as the next seed value to calculate a hash in
chunks; it won't produce the same hash as it would if the same data was
provided in a single call.

If you aren't sure what to provide for a seed, zero is fine. Murmur3 is
not cryptographically secure, so it shouldn't be used for hashing
top-secret data.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
