###### (This function is part of SDL_net, a separate library from SDL.)

# NET_Datagram

The data provided for new incoming packets from
[NET_ReceiveDatagram](NET_ReceiveDatagram.html)().

## Header File

Defined in
[\<SDL3_net/SDL_net.h\>](https://github.com/libsdl-org/SDL_net/blob/main/include/SDL3_net/SDL_net.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct NET_Datagram
{
    NET_Address *addr;  /**< this is unref'd by NET_DestroyDatagram. You only need to ref it if you want to keep it. */
    Uint16 port;  /**< these do not have to come from the same port the receiver is bound to. These are in host byte order, don't byteswap them! */
    Uint8 *buf;  /**< the payload of this datagram. */
    int buflen;  /**< the number of bytes available at `buf`. */
} NET_Datagram;
```

</div>

## Version

This datatype is available since SDL_net 3.0.0.

## See Also

- [NET_ReceiveDatagram](NET_ReceiveDatagram.html)
- [NET_DestroyDatagram](NET_DestroyDatagram.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategorySDLNet](CategorySDLNet.html)
