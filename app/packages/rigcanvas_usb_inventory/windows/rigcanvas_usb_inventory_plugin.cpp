#include "rigcanvas_usb_inventory/rigcanvas_usb_inventory_plugin.h"

#include <windows.h>
#include <setupapi.h>
#include <flutter/plugin_registrar.h>
#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "rigcanvas_usb_inventory/rigcanvas_usb_inventory_plugin_c_api.h"

namespace {

std::wstring GetDeviceProperty(
    HDEVINFO device_info_set,
    SP_DEVINFO_DATA* device_info,
    DWORD property) {
  DWORD data_type = 0;
  DWORD required_size = 0;
  SetupDiGetDeviceRegistryPropertyW(
      device_info_set, device_info, property, &data_type, nullptr, 0, &required_size);
  if (required_size == 0) return L"";

  std::vector<BYTE> buffer(required_size + sizeof(wchar_t), 0);
  if (!SetupDiGetDeviceRegistryPropertyW(
          device_info_set, device_info, property, &data_type,
          buffer.data(), static_cast<DWORD>(buffer.size()), &required_size)) {
    return L"";
  }
  return std::wstring(reinterpret_cast<const wchar_t*>(buffer.data()));
}

std::string ToUtf8(const std::wstring& value) {
  if (value.empty()) return "";
  const int required = WideCharToMultiByte(
      CP_UTF8, 0, value.c_str(), -1, nullptr, 0, nullptr, nullptr);
  if (required <= 1) return "";
  std::string result(static_cast<size_t>(required), '\0');
  WideCharToMultiByte(
      CP_UTF8, 0, value.c_str(), -1, result.data(), required, nullptr, nullptr);
  result.pop_back();
  return result;
}

std::optional<int> ParseUsbId(const std::wstring& hardware_id,
                              const std::wstring& token) {
  const size_t position = hardware_id.find(token);
  if (position == std::wstring::npos || position + token.size() + 4 > hardware_id.size()) {
    return std::nullopt;
  }
  try {
    return std::stoi(hardware_id.substr(position + token.size(), 4), nullptr, 16);
  } catch (...) {
    return std::nullopt;
  }
}

flutter::EncodableList EnumerateUsbDevices() {
  flutter::EncodableList devices;
  HDEVINFO device_info_set = SetupDiGetClassDevsW(
      nullptr, L"USB", nullptr, DIGCF_PRESENT | DIGCF_ALLCLASSES);
  if (device_info_set == INVALID_HANDLE_VALUE) return devices;

  for (DWORD index = 0;; ++index) {
    SP_DEVINFO_DATA device_info = {};
    device_info.cbSize = sizeof(SP_DEVINFO_DATA);
    if (!SetupDiEnumDeviceInfo(device_info_set, index, &device_info)) {
      if (GetLastError() == ERROR_NO_MORE_ITEMS) break;
      continue;
    }

    const std::wstring hardware_id =
        GetDeviceProperty(device_info_set, &device_info, SPDRP_HARDWAREID);
    const auto vendor_id = ParseUsbId(hardware_id, L"VID_");
    const auto product_id = ParseUsbId(hardware_id, L"PID_");
    if (!vendor_id.has_value() || !product_id.has_value()) continue;

    std::wstring name = GetDeviceProperty(
        device_info_set, &device_info, SPDRP_FRIENDLYNAME);
    if (name.empty()) {
      name = GetDeviceProperty(device_info_set, &device_info, SPDRP_DEVICEDESC);
    }
    if (name.empty()) name = L"USB device";

    const std::wstring manufacturer =
        GetDeviceProperty(device_info_set, &device_info, SPDRP_MFG);

    flutter::EncodableMap record;
    record[flutter::EncodableValue("vendorId")] = flutter::EncodableValue(*vendor_id);
    record[flutter::EncodableValue("productId")] = flutter::EncodableValue(*product_id);
    record[flutter::EncodableValue("deviceClass")] = flutter::EncodableValue(0);
    record[flutter::EncodableValue("deviceSubclass")] = flutter::EncodableValue(0);
    record[flutter::EncodableValue("deviceProtocol")] = flutter::EncodableValue(0);
    record[flutter::EncodableValue("name")] = flutter::EncodableValue(ToUtf8(name));
    record[flutter::EncodableValue("manufacturer")] =
        flutter::EncodableValue(ToUtf8(manufacturer));
    record[flutter::EncodableValue("product")] = flutter::EncodableValue(ToUtf8(name));
    record[flutter::EncodableValue("interfacesAvailable")] = flutter::EncodableValue(false);
    record[flutter::EncodableValue("detailLevel")] =
        flutter::EncodableValue("windows-pnp-vid-pid");
    record[flutter::EncodableValue("interfaces")] =
        flutter::EncodableValue(flutter::EncodableList{});
    devices.push_back(flutter::EncodableValue(std::move(record)));
  }

  SetupDiDestroyDeviceInfoList(device_info_set);
  return devices;
}

}  // namespace

RigCanvasUsbInventoryPlugin::RigCanvasUsbInventoryPlugin(
    flutter::PluginRegistrarWindows* registrar) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "com.rigcanvas/usb_inventory",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
}

RigCanvasUsbInventoryPlugin::~RigCanvasUsbInventoryPlugin() = default;

void RigCanvasUsbInventoryPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  registrar->AddPlugin(std::make_unique<RigCanvasUsbInventoryPlugin>(registrar));
}

void RigCanvasUsbInventoryPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "listUsbDevices") {
    result->Success(flutter::EncodableValue(EnumerateUsbDevices()));
    return;
  }
  result->NotImplemented();
}

RIGCANVAS_USB_INVENTORY_EXPORT void
RigCanvasUsbInventoryPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter::PluginRegistrarManager::GetInstance()
      ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar)
      ->AddPlugin(std::make_unique<RigCanvasUsbInventoryPlugin>(
          flutter::PluginRegistrarManager::GetInstance()
              ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar)));
}
