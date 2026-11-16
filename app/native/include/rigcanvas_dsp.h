#ifndef RIGCANVAS_DSP_H
#define RIGCANVAS_DSP_H
#include <stdint.h>
#if defined(_WIN32)
#define RIGCANVAS_DSP_API __declspec(dllexport)
#else
#define RIGCANVAS_DSP_API __attribute__((visibility("default")))
#endif
#ifdef __cplusplus
extern "C" {
#endif
RIGCANVAS_DSP_API uint32_t rg_engine_abi_version(void);
RIGCANVAS_DSP_API void* rg_engine_create(uint32_t sample_rate, uint32_t channels);
RIGCANVAS_DSP_API void rg_engine_destroy(void* handle);
RIGCANVAS_DSP_API int32_t rg_engine_add_node(void* handle, int32_t node_type, int32_t mode, int32_t enabled);
RIGCANVAS_DSP_API int32_t rg_engine_set_parameter(void* handle, uint32_t node_index, uint32_t parameter_index, float value);
RIGCANVAS_DSP_API int32_t rg_engine_set_cabinet_ir(void* handle, uint32_t node_index, const float* samples, uint32_t sample_count);
RIGCANVAS_DSP_API int32_t rg_engine_process(void* handle, float* interleaved, uint32_t frame_count);
RIGCANVAS_DSP_API int32_t rg_engine_run_test_tone(void* handle, float frequency_hz, uint32_t duration_ms);
RIGCANVAS_DSP_API double rg_engine_input_rms_db(void* handle);
RIGCANVAS_DSP_API double rg_engine_output_rms_db(void* handle);
RIGCANVAS_DSP_API double rg_engine_input_peak_db(void* handle);
RIGCANVAS_DSP_API double rg_engine_output_peak_db(void* handle);
RIGCANVAS_DSP_API uint32_t rg_engine_processed_frames(void* handle);
RIGCANVAS_DSP_API uint32_t rg_engine_enabled_node_count(void* handle);
#ifdef __cplusplus
}
#endif
#endif
