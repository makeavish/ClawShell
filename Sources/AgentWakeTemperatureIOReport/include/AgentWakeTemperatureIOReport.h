#ifndef AgentWakeTemperatureIOReport_h
#define AgentWakeTemperatureIOReport_h

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

enum {
    AgentWakeIOReportTemperatureStatusOK = 0,
    AgentWakeIOReportTemperatureStatusUnavailable = 1,
    AgentWakeIOReportTemperatureStatusParseFailed = 2,
    AgentWakeIOReportTemperatureStatusUnsupportedHardware = 3
};

typedef struct AgentWakeIOReportTemperatureReading {
    double celsius;
    int32_t sampleCount;
    int32_t scaleVerifiedCount;
    int32_t invalidSampleCount;
    int32_t apiFailureCount;
} AgentWakeIOReportTemperatureReading;

int32_t AgentWakeIOReportReadTemperature(AgentWakeIOReportTemperatureReading *reading);

#ifdef __cplusplus
}
#endif

#endif
