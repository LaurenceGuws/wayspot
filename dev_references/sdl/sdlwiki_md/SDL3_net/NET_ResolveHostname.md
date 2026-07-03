###### (This function is part of SDL_net, a separate library from SDL.)

# NET_ResolveHostname

Resolve a human-readable hostname.

## Header File

Defined in
[\<SDL3_net/SDL_net.h\>](https://github.com/libsdl-org/SDL_net/blob/main/include/SDL3_net/SDL_net.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
NET_Address * NET_ResolveHostname(const char *host);
```

</div>

## Function Parameters

|               |          |                          |
|---------------|----------|--------------------------|
| const char \* | **host** | The hostname to resolve. |

## Return Value

([NET_Address](NET_Address.html) \*) Returns A new
[NET_Address](NET_Address.html) on success, NULL on error; call
SDL_GetError() for details.

## Remarks

SDL_net doesn't operate on human-readable hostnames (like
`www.libsdl.org` but on computer-readable addresses. This function
converts from one to the other. This process is known as "resolving" an
address.

You can also use this to turn IP address strings (like "159.203.69.7")
into [NET_Address](NET_Address.html) objects.

Note that resolving an address is an asynchronous operation, since the
library will need to ask a server on the internet to get the information
it needs, and this can take time (and possibly fail later). This
function will not block. It either returns NULL (catastrophic failure)
or an unresolved [NET_Address](NET_Address.html). Until the address
resolves, it can't be used.

If you want to block until the resolution is finished, you can call
[NET_WaitUntilResolved](NET_WaitUntilResolved.html)(). Otherwise, you
can do a non-blocking check with
[NET_GetAddressStatus](NET_GetAddressStatus.html)().

When you are done with the returned [NET_Address](NET_Address.html),
call [NET_UnrefAddress](NET_UnrefAddress.html)() to dispose of it. You
need to do this even if resolution later fails asynchronously.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_net 3.0.0.

## See Also

- [NET_WaitUntilResolved](NET_WaitUntilResolved.html)
- [NET_GetAddressStatus](NET_GetAddressStatus.html)
- [NET_RefAddress](NET_RefAddress.html)
- [NET_UnrefAddress](NET_UnrefAddress.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLNet](CategorySDLNet.html)
