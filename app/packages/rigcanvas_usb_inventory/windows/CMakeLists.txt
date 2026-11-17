cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "rigcanvas_usb_inventory")
project(${PROJECT_NAME} LANGUAGES CXX)

add_library(${PROJECT_NAME} SHARED
  "rigcanvas_usb_inventory_plugin.cpp"
)

apply_standard_settings(${PROJECT_NAME})
target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
target_link_libraries(${PROJECT_NAME} PRIVATE flutter flutter_wrapper_plugin setupapi)
target_include_directories(${PROJECT_NAME} PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
set_target_properties(${PROJECT_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
)
