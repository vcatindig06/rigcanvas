package com.rigcanvas.usbinventory;

import android.content.Context;
import android.hardware.usb.UsbConstants;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbInterface;
import android.hardware.usb.UsbEndpoint;
import android.hardware.usb.UsbManager;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public final class RigCanvasUsbInventoryPlugin
        implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private MethodChannel channel;
    private UsbManager usbManager;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        usbManager = (UsbManager) binding.getApplicationContext()
                .getSystemService(Context.USB_SERVICE);
        channel = new MethodChannel(
                binding.getBinaryMessenger(),
                "com.rigcanvas/usb_inventory");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (!"listUsbDevices".equals(call.method)) {
            result.notImplemented();
            return;
        }

        try {
            List<UsbDevice> attached = new ArrayList<>(usbManager.getDeviceList().values());
            attached.sort(Comparator
                    .comparingInt(UsbDevice::getVendorId)
                    .thenComparingInt(UsbDevice::getProductId)
                    .thenComparing(UsbDevice::getDeviceName));

            List<Map<String, Object>> records = new ArrayList<>();
            for (UsbDevice device : attached) records.add(toMap(device));
            result.success(records);
        } catch (SecurityException exception) {
            result.error("USB_ENUMERATION_DENIED",
                    "Android denied USB device enumeration.", null);
        } catch (Exception exception) {
            result.error("USB_ENUMERATION_FAILED",
                    exception.getMessage() == null
                            ? "USB enumeration failed."
                            : exception.getMessage(),
                    null);
        }
    }

    private Map<String, Object> toMap(UsbDevice device) {
        List<Map<String, Object>> interfaceRecords = new ArrayList<>();
        for (int interfaceIndex = 0;
             interfaceIndex < device.getInterfaceCount();
             interfaceIndex++) {
            UsbInterface usbInterface = device.getInterface(interfaceIndex);
            List<Map<String, Object>> endpointRecords = new ArrayList<>();

            for (int endpointIndex = 0;
                 endpointIndex < usbInterface.getEndpointCount();
                 endpointIndex++) {
                UsbEndpoint endpoint = usbInterface.getEndpoint(endpointIndex);
                Map<String, Object> endpointMap = new HashMap<>();
                endpointMap.put("address", endpoint.getAddress());
                endpointMap.put("direction",
                        endpoint.getDirection() == UsbConstants.USB_DIR_IN ? "in" : "out");
                endpointMap.put("transferType", transferTypeName(endpoint.getType()));
                endpointMap.put("maxPacketSize", endpoint.getMaxPacketSize());
                endpointMap.put("interval", endpoint.getInterval());
                endpointRecords.add(endpointMap);
            }

            Map<String, Object> interfaceMap = new HashMap<>();
            interfaceMap.put("id", usbInterface.getId());
            interfaceMap.put("interfaceClass", usbInterface.getInterfaceClass());
            interfaceMap.put("interfaceSubclass", usbInterface.getInterfaceSubclass());
            interfaceMap.put("interfaceProtocol", usbInterface.getInterfaceProtocol());
            interfaceMap.put("endpoints", endpointRecords);
            interfaceRecords.add(interfaceMap);
        }

        Map<String, Object> record = new HashMap<>();
        record.put("vendorId", device.getVendorId());
        record.put("productId", device.getProductId());
        record.put("deviceClass", device.getDeviceClass());
        record.put("deviceSubclass", device.getDeviceSubclass());
        record.put("deviceProtocol", device.getDeviceProtocol());
        record.put("name", device.getProductName() == null
                ? "USB device" : device.getProductName());
        record.put("manufacturer", device.getManufacturerName());
        record.put("product", device.getProductName());
        record.put("interfacesAvailable", true);
        record.put("detailLevel", "android-usb-interface-and-endpoint-descriptors");
        record.put("interfaces", interfaceRecords);
        return record;
    }

    private String transferTypeName(int type) {
        switch (type) {
            case UsbConstants.USB_ENDPOINT_XFER_CONTROL: return "control";
            case UsbConstants.USB_ENDPOINT_XFER_ISOC: return "isochronous";
            case UsbConstants.USB_ENDPOINT_XFER_BULK: return "bulk";
            case UsbConstants.USB_ENDPOINT_XFER_INT: return "interrupt";
            default: return "unknown";
        }
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        usbManager = null;
    }
}
