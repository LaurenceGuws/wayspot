###### (This function is part of SDL_net, a separate library from SDL.)

# NET_DestroyDatagram

Dispose of a datagram packet previously received.

## Header File

Defined in
[\<SDL3_net/SDL_net.h\>](https://github.com/libsdl-org/SDL_net/blob/main/include/SDL3_net/SDL_net.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void NET_DestroyDatagram(NET_Datagram *dgram);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [NET_Datagram](NET_Datagram.html) \* | **dgram** | the datagram packet to destroy. |

## Remarks

You must pass packets received through
[NET_ReceiveDatagram](NET_ReceiveDatagram.html) to this function when
you are done with them. This will free resources used by this packet and
unref its [NET_Address](NET_Address.html).

If you want to save the sender's address from the packet past this time,
it is safe to call [NET_RefAddress](NET_RefAddress.html)() on the
address and hold onto its pointer, so long as you call
[NET_UnrefAddress](NET_UnrefAddress.html)() on it when you are done with
it.

Once you call this function, the datagram pointer becomes invalid and
should not be used again by the app.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_net 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLNet](CategorySDLNet.html)
