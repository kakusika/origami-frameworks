#pragma once
#include <cstdint>

// Simple C++ bootstrap helper for QQmlApplicationEngine instantiation and QML loading.

extern "C" {

uint64_t createEngine();
bool loadQml(uint64_t enginePtr, const char* qmlUrlUtf8);
uint64_t rootWindowOf(uint64_t enginePtr);
void destroyEngine(uint64_t enginePtr);

} // extern "C"
