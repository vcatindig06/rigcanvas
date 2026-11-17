cmake_minimum_required(VERSION 3.14)
set(PLUGIN_NAME "rigcanvas_usb_inventory_plugin")
project(${PLUGIN_NAME} LANGUAGES CXX)

add_library(${PLUGIN_NAME} SHARED
  "rigcanvas_usb_inventory_plugin.cpp"
)

apply_standard_settings(${PLUGIN_NAME})
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin setupapi)
target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
)
