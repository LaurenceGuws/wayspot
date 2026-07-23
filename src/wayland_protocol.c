#include "wayland_protocol.h"

#include <stddef.h>
#include <viewporter-client.h>
#include <wlr-layer-shell-unstable-v1-client.h>
#include <wlr-layer-shell-unstable-v1.c>

_Static_assert(
    sizeof(struct wayspot_layer_listener) == sizeof(struct zwlr_layer_surface_v1_listener),
    "layer listener ABI changed");
_Static_assert(
    offsetof(struct wayspot_layer_listener, configure) ==
        offsetof(struct zwlr_layer_surface_v1_listener, configure),
    "layer configure listener ABI changed");
_Static_assert(
    offsetof(struct wayspot_layer_listener, closed) ==
        offsetof(struct zwlr_layer_surface_v1_listener, closed),
    "layer closed listener ABI changed");

const struct wl_interface *wayspot_viewporter_interface(void) {
    return &wp_viewporter_interface;
}

const struct wl_interface *wayspot_layer_shell_interface(void) {
    return &zwlr_layer_shell_v1_interface;
}

void wayspot_viewporter_destroy(struct wp_viewporter *proxy) {
    wp_viewporter_destroy(proxy);
}

struct wp_viewport *wayspot_viewporter_get_viewport(
    struct wp_viewporter *proxy,
    struct wl_surface *surface) {
    return wp_viewporter_get_viewport(proxy, surface);
}

void wayspot_viewport_destroy(struct wp_viewport *proxy) {
    wp_viewport_destroy(proxy);
}

void wayspot_viewport_set_destination(struct wp_viewport *proxy, int32_t width, int32_t height) {
    wp_viewport_set_destination(proxy, width, height);
}

void wayspot_layer_shell_destroy(struct zwlr_layer_shell_v1 *proxy) {
    zwlr_layer_shell_v1_destroy(proxy);
}

struct zwlr_layer_surface_v1 *wayspot_layer_shell_get_surface(
    struct zwlr_layer_shell_v1 *proxy,
    struct wl_surface *surface,
    struct wl_output *output,
    uint32_t layer,
    const char *name) {
    return zwlr_layer_shell_v1_get_layer_surface(proxy, surface, output, layer, name);
}

int wayspot_layer_surface_add_listener(
    struct zwlr_layer_surface_v1 *proxy,
    const struct wayspot_layer_listener *listener,
    void *data) {
    return zwlr_layer_surface_v1_add_listener(
        proxy,
        (const struct zwlr_layer_surface_v1_listener *)listener,
        data);
}

void wayspot_layer_surface_set_size(
    struct zwlr_layer_surface_v1 *proxy,
    uint32_t width,
    uint32_t height) {
    zwlr_layer_surface_v1_set_size(proxy, width, height);
}

void wayspot_layer_surface_set_anchor(struct zwlr_layer_surface_v1 *proxy, uint32_t anchor) {
    zwlr_layer_surface_v1_set_anchor(proxy, anchor);
}

void wayspot_layer_surface_set_exclusive_zone(struct zwlr_layer_surface_v1 *proxy, int32_t zone) {
    zwlr_layer_surface_v1_set_exclusive_zone(proxy, zone);
}

void wayspot_layer_surface_set_keyboard(struct zwlr_layer_surface_v1 *proxy, uint32_t mode) {
    zwlr_layer_surface_v1_set_keyboard_interactivity(proxy, mode);
}

void wayspot_layer_surface_ack_configure(struct zwlr_layer_surface_v1 *proxy, uint32_t serial) {
    zwlr_layer_surface_v1_ack_configure(proxy, serial);
}

void wayspot_layer_surface_destroy(struct zwlr_layer_surface_v1 *proxy) {
    zwlr_layer_surface_v1_destroy(proxy);
}
