#ifndef RIGCANVAS_USB_INVENTORY_PLUGIN_C_API_H_
#define RIGCANVAS_USB_INVENTORY_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#ifdef _WIN32
#define RIGCANVAS_USB_INVENTORY_EXPORT __declspec(dllexport)
#else
#define RIGCANVAS_USB_INVENTORY_EXPORT
#endif

RIGCANVAS_USB_INVENTORY_EXPORT void
RigCanvasUsbInventoryPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#endif
