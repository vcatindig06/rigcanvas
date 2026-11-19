#ifndef RIGCANVAS_USB_INVENTORY_PLUGIN_H_
#define RIGCANVAS_USB_INVENTORY_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <memory>

class RigCanvasUsbInventoryPlugin : public flutter::Plugin {
 public:
  explicit RigCanvasUsbInventoryPlugin(flutter::PluginRegistrarWindows* registrar);
  ~RigCanvasUsbInventoryPlugin() override;

  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif
