#!/usr/bin/env python3
"""A real short-lived SNI item on a private DBus session (test-only)."""

import dbus, dbus.service, dbus.mainloop.glib, pathlib, sys, os
from gi.repository import GLib

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
service = "org.kde.StatusNotifierItem-4242-1"
name = dbus.service.BusName(service, bus=bus, do_not_queue=True)
record = pathlib.Path(sys.argv[1])


def pixmap():
    pixels = bytearray()
    for y in range(22):
        for x in range(22):
            interior = 2 < x < 19 and 2 < y < 19
            a, r, g, b = (255, 35, 210, 115) if interior else (255, 18, 30, 25)
            if 7 <= x <= 14 and 10 <= y <= 11:
                a, r, g, b = (255, 240, 244, 250)
            pixels.extend((a, r, g, b))
    return dbus.Array(
        [
            dbus.Struct(
                (dbus.Int32(22), dbus.Int32(22), dbus.ByteArray(bytes(pixels))),
                signature="(iiay)",
            )
        ],
        signature="(iiay)",
    )


class Item(dbus.service.Object):
    def __init__(self):
        super().__init__(bus, "/StatusNotifierItem")

    def props(self):
        return dbus.Dictionary(
            {
                "Id": dbus.String("wayspot-test"),
                "Title": dbus.String("Wayspot Tray Test"),
                "Status": dbus.String("Active"),
                "IconName": dbus.String(""),
                "IconPixmap": pixmap(),
                "ItemIsMenu": dbus.Boolean(False),
                "Menu": dbus.ObjectPath("/TrayMenu"),
            },
            signature="sv",
        )

    @dbus.service.method(
        "org.freedesktop.DBus.Properties", in_signature="s", out_signature="a{sv}"
    )
    def GetAll(self, interface):
        record.with_suffix(".fetch").write_text(interface)
        if interface not in (
            "org.kde.StatusNotifierItem",
            "org.freedesktop.StatusNotifierItem",
        ) or (
            os.getenv("WAYSPOT_TRAY_MOCK_FD_ONLY")
            and interface == "org.kde.StatusNotifierItem"
        ):
            return dbus.Dictionary({}, signature="sv")
        return self.props()

    @dbus.service.method(
        "org.freedesktop.DBus.Properties", in_signature="ss", out_signature="v"
    )
    def Get(self, interface, property):
        return self.props()[property]

    @dbus.service.method(
        "org.freedesktop.StatusNotifierItem"
        if os.getenv("WAYSPOT_TRAY_MOCK_FD_ONLY")
        else "org.kde.StatusNotifierItem",
        in_signature="ii",
        out_signature="",
    )
    def Activate(self, x, y):
        record.write_text(f"ACTIVATE {x} {y}\n")

    @dbus.service.method(
        "org.kde.StatusNotifierItem", in_signature="ii", out_signature=""
    )
    def ContextMenu(self, x, y):
        record.write_text(f"CONTEXT {x} {y}\n")

    @dbus.service.method(
        "org.kde.StatusNotifierItem", in_signature="ii", out_signature=""
    )
    def SecondaryActivate(self, x, y):
        record.write_text(f"SECONDARY {x} {y}\n")


class Menu(dbus.service.Object):
    def __init__(self):
        super().__init__(bus, "/TrayMenu")

    @dbus.service.method(
        "com.canonical.dbusmenu", in_signature="iias", out_signature="u(ia{sv}av)"
    )
    def GetLayout(self, parent, depth, names):
        props = dbus.Dictionary(
            {
                "label": dbus.String("Open Mock Settings", variant_level=1),
                "enabled": dbus.Boolean(True, variant_level=1),
            },
            signature="sv",
        )
        child = dbus.Struct(
            (dbus.Int32(7), props, dbus.Array([], signature="v")),
            signature="(ia{sv}av)",
            variant_level=1,
        )
        root = dbus.Struct(
            (
                dbus.Int32(parent),
                dbus.Dictionary({}, signature="sv"),
                dbus.Array([child], signature="v"),
            ),
            signature="(ia{sv}av)",
        )
        return (dbus.UInt32(1), root)

    @dbus.service.method(
        "com.canonical.dbusmenu", in_signature="isvu", out_signature=""
    )
    def Event(self, item_id, event_id, extra, timestamp):
        record.write_text(f"MENU {item_id} {event_id}\n")


item = Item()
menu = Menu()
loop = GLib.MainLoop()


def register():
    try:
        watcher = bus.get_object(
            "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher"
        )
        watcher.RegisterStatusNotifierItem(
            service, dbus_interface="org.kde.StatusNotifierWatcher", timeout=1.0
        )
        print("MOCK_REGISTERED", service, flush=True)
        return False
    except dbus.DBusException:
        return True


GLib.timeout_add(65, register)
loop.run()
