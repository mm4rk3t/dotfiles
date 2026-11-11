#!/usr/bin/env python3
"""Framed stalonetray popup that follows light/dark mode without restarting.

i3 has one border color for every window (the accent once hovered/focused),
and this stalonetray build can't draw a background pixmap, so the popup is a
small GTK window, a 1px border around a bg-colored inside, with stalonetray
reparented into it at (1, 1). stalonetray runs with --parent-bg, so it and its
icons show the frame's X background color.

Colors come from ~/.cache/theme-mode.ini (bg, and bg-active for the border).
SIGUSR1 rereads them and repaints in place: restarting the tray would lose the
icons of apps that only dock at launch (Electron ones: Slack, Spotify, ...).

traytoggle.sh sizes the frame to the tray's size hints + 2px when it shows
the popup (stalonetray grows as icons dock).

    trayframe.py STALONETRAY_ARGS...
"""
import configparser
import ctypes
import os
import signal
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkX11", "3.0")  # gives GdkWindow.get_xid()
from gi.repository import Gdk, GdkX11, GLib, Gtk  # noqa: E402,F401

THEME_INI = os.path.expanduser("~/.cache/theme-mode.ini")


def read_colors():
    ini = configparser.ConfigParser()
    ini.read(THEME_INI)
    t = ini["theme"] if ini.has_section("theme") else {}
    return t.get("bg", "#222222"), t.get("bg-active", "#444444")


def rgb(hex_color):
    v = int(hex_color.lstrip("#"), 16)
    return ((v >> 16) & 255) / 255, ((v >> 8) & 255) / 255, (v & 255) / 255


# Plain Xlib for the tray window: GDK caches a foreign window's parent and
# geometry, so it can't tell when i3 has taken the tray back
X = ctypes.cdll.LoadLibrary("libX11.so.6")
X.XOpenDisplay.restype = ctypes.c_void_p
X.XOpenDisplay.argtypes = [ctypes.c_char_p]
X.XQueryTree.argtypes = [ctypes.c_void_p, ctypes.c_ulong] + [ctypes.c_void_p] * 4
X.XReparentWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_int, ctypes.c_int]
X.XMapWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
X.XSetWindowBackground.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong]
X.XClearArea.argtypes = [ctypes.c_void_p, ctypes.c_ulong] + [ctypes.c_int] * 2 + [ctypes.c_uint] * 2 + [ctypes.c_int]
X.XFlush.argtypes = [ctypes.c_void_p]
X.XMoveWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_int]
X.XTranslateCoordinates.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_int,
                                    ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
X.XFree.argtypes = [ctypes.c_void_p]
X.XDefaultRootWindow.restype = ctypes.c_ulong
X.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
X.XQueryPointer.argtypes = [ctypes.c_void_p, ctypes.c_ulong] + [ctypes.c_void_p] * 7
dpy = X.XOpenDisplay(None)

colors = {"bg": None, "border": None}

win = Gtk.Window(title="trayframe")
win.set_wmclass("trayframe", "trayframe")
win.set_decorated(False)
win.set_skip_taskbar_hint(True)
win.set_app_paintable(True)
win.set_size_request(32, 32)
win.connect("destroy", Gtk.main_quit)


def on_draw(widget, cr):
    w, h = widget.get_allocated_width(), widget.get_allocated_height()
    cr.set_source_rgb(*rgb(colors["border"]))
    cr.paint()
    cr.set_source_rgb(*rgb(colors["bg"]))
    cr.rectangle(1, 1, w - 2, h - 2)
    cr.fill()
    return True


win.connect("draw", on_draw)
win.show()  # i3 floats it and parks it in the scratchpad (for_window rule)
frame_xid = win.get_window().get_xid()

tray = subprocess.Popen(["stalonetray", "--parent-bg", *sys.argv[1:]])
state = {"xid": None}


def query_tree(xid):
    """(parent, [children]) of an X window, or (None, []) if it's gone."""
    root, parent, children = ctypes.c_ulong(), ctypes.c_ulong(), ctypes.POINTER(ctypes.c_ulong)()
    n = ctypes.c_uint()
    if not X.XQueryTree(dpy, xid, ctypes.byref(root), ctypes.byref(parent),
                        ctypes.byref(children), ctypes.byref(n)):
        return None, []
    kids = [children[i] for i in range(n.value)]
    if children:
        X.XFree(children)
    return parent.value, kids


def repaint(xid):
    """Clear a window and its subwindows so ParentRelative backgrounds (the
    tray and the icons in it) pick up the frame's new color."""
    X.XClearArea(dpy, xid, 0, 0, 0, 0, 1)
    for kid in query_tree(xid)[1]:
        repaint(kid)


def apply_colors(*_):
    colors["bg"], colors["border"] = read_colors()
    X.XSetWindowBackground(dpy, frame_xid, int(colors["bg"].lstrip("#"), 16))
    win.queue_draw()
    if state["xid"]:
        repaint(state["xid"])
    X.XFlush(dpy)
    return True  # keep the signal handler installed


def find_tray():
    out = subprocess.run(["xdotool", "search", "--classname", "^stalonetray$"],
                         capture_output=True, text=True).stdout.split()
    return int(out[0]) if out else None


def position_in_frame(xid):
    x, y, child = ctypes.c_int(), ctypes.c_int(), ctypes.c_ulong()
    X.XTranslateCoordinates(dpy, xid, frame_xid, 0, 0, ctypes.byref(x), ctypes.byref(y),
                            ctypes.byref(child))
    return x.value, y.value


def tick():
    """Keep the tray inside the frame. i3 manages it when it first maps and,
    once it loses it, reparents it back to the root window (more than once
    when i3 reloads), so check and pull it back in whenever that happens."""
    if tray.poll() is not None:
        Gtk.main_quit()
        return False
    if state["xid"] is None:
        state["xid"] = find_tray()
    xid = state["xid"]
    parent = query_tree(xid)[0] if xid else None
    if parent not in (None, frame_xid):
        X.XReparentWindow(dpy, xid, frame_xid, 1, 1)
        X.XMapWindow(dpy, xid)
        X.XFlush(dpy)
    elif parent == frame_xid and position_in_frame(xid) != (1, 1):
        # stalonetray thinks it's a top-level window: when it grows (a new
        # icon row) it moves itself to root coordinates, out of the frame
        X.XMoveWindow(dpy, xid, 1, 1)
        X.XFlush(dpy)
    return True


def pointer():
    """(x, y, button mask) of the mouse, in root coordinates."""
    r, c = ctypes.c_ulong(), ctypes.c_ulong()
    rx, ry, wx, wy = (ctypes.c_int() for _ in range(4))
    mask = ctypes.c_uint()
    X.XQueryPointer(dpy, X.XDefaultRootWindow(dpy), *(ctypes.byref(v) for v in
                    (r, c, rx, ry, wx, wy, mask)))
    return rx.value, ry.value, mask.value & (0x1f << 8)  # Button1-5 masks


CLOSE = [os.path.join(os.path.dirname(os.path.abspath(__file__)), "traytoggle.sh"), "close"]
watch = {"id": None, "buttons": 0}


def check_click():
    """Close the popup when a mouse button goes down outside it, like a menu.
    Polls the pointer instead of grabbing it: a grab would steal the clicks
    meant for the icons, which belong to other apps."""
    x, y, buttons = pointer()
    pressed = buttons & ~watch["buttons"]
    watch["buttons"] = buttons
    if pressed:
        gw = win.get_window()
        _, fx, fy = gw.get_origin()
        if not (fx <= x < fx + gw.get_width() and fy <= y < fy + gw.get_height()):
            subprocess.Popen(CLOSE)
    return True


def on_map(*_):
    # Buttons already down (the click on the bar arrow that opened it) don't count
    watch["buttons"] = pointer()[2]
    if watch["id"] is None:
        watch["id"] = GLib.timeout_add(25, check_click)


def on_unmap(*_):
    if watch["id"] is not None:
        GLib.source_remove(watch["id"])
        watch["id"] = None


win.connect("map-event", on_map)
win.connect("unmap-event", on_unmap)

apply_colors()
GLib.timeout_add(300, tick)
GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, apply_colors)
# Quit cleanly on SIGTERM/SIGINT so the tray goes too (stalonetray can ignore
# SIGTERM, hence kill)
for sig in (signal.SIGTERM, signal.SIGINT):
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, Gtk.main_quit)
try:
    Gtk.main()
finally:
    tray.kill()
