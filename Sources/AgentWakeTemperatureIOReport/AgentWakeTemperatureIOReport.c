#include "AgentWakeTemperatureIOReport.h"

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <float.h>
#include <stdint.h>

#define AGENTWAKE_IOREPORT_GETUNIT_QUANTITY(unit) (((uint64_t)(unit) >> 56) & 0xff)
#define AGENTWAKE_IOREPORT_GETUNIT_SCALE(unit) ((uint64_t)(unit) & 0x00ffffffffffffff)
#define AGENTWAKE_IOREPORT_QUANTITY_TEMPERATURE 10
#define AGENTWAKE_IOREPORT_SCALE_UNITY 0

typedef CFMutableDictionaryRef (*AgentWakeIOReportCopyChannelsInGroupFn)(CFStringRef, CFStringRef, uint64_t, uint64_t, uint64_t);
typedef CFTypeRef (*AgentWakeIOReportCreateSubscriptionFn)(CFTypeRef, CFMutableDictionaryRef, CFMutableDictionaryRef *, uint64_t, CFErrorRef *);
typedef CFDictionaryRef (*AgentWakeIOReportCreateSamplesFn)(CFTypeRef, CFTypeRef, CFTypeRef);
typedef void (*AgentWakeIOReportIterateFn)(CFTypeRef, int (^)(CFDictionaryRef));
typedef CFStringRef (*AgentWakeIOReportChannelGetChannelNameFn)(CFDictionaryRef);
typedef uint64_t (*AgentWakeIOReportChannelGetUnitFn)(CFDictionaryRef);
typedef int64_t (*AgentWakeIOReportSimpleGetIntegerValueFn)(CFDictionaryRef, int);

typedef struct AgentWakeIOReportFunctions {
    void *handle;
    AgentWakeIOReportCopyChannelsInGroupFn copyChannelsInGroup;
    AgentWakeIOReportCreateSubscriptionFn createSubscription;
    AgentWakeIOReportCreateSamplesFn createSamples;
    AgentWakeIOReportIterateFn iterate;
    AgentWakeIOReportChannelGetChannelNameFn channelGetChannelName;
    AgentWakeIOReportChannelGetUnitFn channelGetUnit;
    AgentWakeIOReportSimpleGetIntegerValueFn simpleGetIntegerValue;
} AgentWakeIOReportFunctions;

typedef struct AgentWakeIOReportProbeResult {
    int32_t sampleCount;
    int32_t scaleVerifiedCount;
    int32_t invalidSampleCount;
    double maxCelsius;
    int32_t channelGroupFound;
    int32_t apiFailureCount;
} AgentWakeIOReportProbeResult;

static void *AgentWakeIOReportSymbol(void *handle, const char *name) {
    return dlsym(handle, name);
}

static int AgentWakeIOReportLoadFunctions(AgentWakeIOReportFunctions *functions) {
    if (!functions) {
        return 0;
    }

    void *handle = dlopen("/usr/lib/libIOReport.dylib", RTLD_LAZY | RTLD_LOCAL);
    if (!handle) {
        return 0;
    }

    functions->handle = handle;
    functions->copyChannelsInGroup = (AgentWakeIOReportCopyChannelsInGroupFn)AgentWakeIOReportSymbol(handle, "IOReportCopyChannelsInGroup");
    functions->createSubscription = (AgentWakeIOReportCreateSubscriptionFn)AgentWakeIOReportSymbol(handle, "IOReportCreateSubscription");
    functions->createSamples = (AgentWakeIOReportCreateSamplesFn)AgentWakeIOReportSymbol(handle, "IOReportCreateSamples");
    functions->iterate = (AgentWakeIOReportIterateFn)AgentWakeIOReportSymbol(handle, "IOReportIterate");
    functions->channelGetChannelName = (AgentWakeIOReportChannelGetChannelNameFn)AgentWakeIOReportSymbol(handle, "IOReportChannelGetChannelName");
    functions->channelGetUnit = (AgentWakeIOReportChannelGetUnitFn)AgentWakeIOReportSymbol(handle, "IOReportChannelGetUnit");
    functions->simpleGetIntegerValue = (AgentWakeIOReportSimpleGetIntegerValueFn)AgentWakeIOReportSymbol(handle, "IOReportSimpleGetIntegerValue");

    if (!functions->copyChannelsInGroup ||
        !functions->createSubscription ||
        !functions->createSamples ||
        !functions->iterate ||
        !functions->channelGetChannelName ||
        !functions->channelGetUnit ||
        !functions->simpleGetIntegerValue) {
        dlclose(handle);
        functions->handle = NULL;
        return 0;
    }

    return 1;
}

static void AgentWakeIOReportUnloadFunctions(AgentWakeIOReportFunctions *functions) {
    if (functions && functions->handle) {
        dlclose(functions->handle);
        functions->handle = NULL;
    }
}

static int AgentWakeIOReportIsTemperatureChannel(CFStringRef value) {
    if (!value) {
        return 0;
    }

    CFRange range = CFRangeMake(0, CFStringGetLength(value));
    return CFStringFindWithOptions(value, CFSTR("Temp"), range, kCFCompareCaseInsensitive, NULL);
}

static int AgentWakeIOReportIsScaleVerified(uint64_t unit) {
    uint64_t quantity = AGENTWAKE_IOREPORT_GETUNIT_QUANTITY(unit);
    uint64_t scale = AGENTWAKE_IOREPORT_GETUNIT_SCALE(unit);
    return quantity == AGENTWAKE_IOREPORT_QUANTITY_TEMPERATURE && scale == AGENTWAKE_IOREPORT_SCALE_UNITY;
}

static AgentWakeIOReportProbeResult AgentWakeIOReportProbe(
    const AgentWakeIOReportFunctions *functions,
    CFStringRef group,
    CFStringRef subgroup
) {
    AgentWakeIOReportProbeResult result = {0, 0, 0, -DBL_MAX, 0, 0};
    CFMutableDictionaryRef channels = functions->copyChannelsInGroup(group, subgroup, 0, 0, 0);
    if (!channels) {
        return result;
    }
    result.channelGroupFound = 1;

    CFMutableDictionaryRef subscribed = NULL;
    CFErrorRef error = NULL;
    CFTypeRef subscription = functions->createSubscription(NULL, channels, &subscribed, 0, &error);
    if (!subscription) {
        result.apiFailureCount += 1;
        if (error) {
            CFRelease(error);
        }
        CFRelease(channels);
        return result;
    }

    CFDictionaryRef samples = functions->createSamples(subscription, subscribed, NULL);
    if (!samples) {
        result.apiFailureCount += 1;
        CFRelease(subscription);
        if (subscribed) {
            CFRelease(subscribed);
        }
        CFRelease(channels);
        return result;
    }

    __block AgentWakeIOReportProbeResult blockResult = result;
    functions->iterate(samples, ^int(CFDictionaryRef sample) {
        CFStringRef channelName = functions->channelGetChannelName(sample);
        if (!AgentWakeIOReportIsTemperatureChannel(channelName)) {
            return 0;
        }

        int64_t value = functions->simpleGetIntegerValue(sample, 0);
        if (value < -40 || value > 125) {
            blockResult.invalidSampleCount += 1;
            return 0;
        }

        blockResult.sampleCount += 1;
        double celsius = (double)value;
        if (celsius > blockResult.maxCelsius) {
            blockResult.maxCelsius = celsius;
        }

        if (AgentWakeIOReportIsScaleVerified(functions->channelGetUnit(sample))) {
            blockResult.scaleVerifiedCount += 1;
        }
        return 0;
    });

    CFRelease(samples);
    CFRelease(subscription);
    if (subscribed) {
        CFRelease(subscribed);
    }
    CFRelease(channels);
    return blockResult;
}

int32_t AgentWakeIOReportReadTemperature(AgentWakeIOReportTemperatureReading *reading) {
    if (!reading) {
        return AgentWakeIOReportTemperatureStatusParseFailed;
    }

    reading->celsius = 0;
    reading->sampleCount = 0;
    reading->scaleVerifiedCount = 0;
    reading->invalidSampleCount = 0;
    reading->apiFailureCount = 0;

    AgentWakeIOReportFunctions functions = {0};
    if (!AgentWakeIOReportLoadFunctions(&functions)) {
        return AgentWakeIOReportTemperatureStatusUnsupportedHardware;
    }

    struct Probe {
        CFStringRef group;
        CFStringRef subgroup;
    } probes[] = {
        {CFSTR("ANS2"), CFSTR("MSP0")},
        {CFSTR("ANS2"), CFSTR("MSP1")},
        {CFSTR("ANS2"), CFSTR("MSP2")},
        {CFSTR("ANS2"), CFSTR("MSP3")}
    };

    AgentWakeIOReportProbeResult combined = {0, 0, 0, -DBL_MAX, 0, 0};
    for (size_t index = 0; index < sizeof(probes) / sizeof(probes[0]); index++) {
        AgentWakeIOReportProbeResult result = AgentWakeIOReportProbe(&functions, probes[index].group, probes[index].subgroup);
        combined.sampleCount += result.sampleCount;
        combined.scaleVerifiedCount += result.scaleVerifiedCount;
        combined.invalidSampleCount += result.invalidSampleCount;
        combined.channelGroupFound = combined.channelGroupFound || result.channelGroupFound;
        combined.apiFailureCount += result.apiFailureCount;
        if (result.maxCelsius > combined.maxCelsius) {
            combined.maxCelsius = result.maxCelsius;
        }
    }

    AgentWakeIOReportUnloadFunctions(&functions);

    reading->sampleCount = combined.sampleCount;
    reading->scaleVerifiedCount = combined.scaleVerifiedCount;
    reading->invalidSampleCount = combined.invalidSampleCount;
    reading->apiFailureCount = combined.apiFailureCount;

    if (combined.invalidSampleCount > 0) {
        return AgentWakeIOReportTemperatureStatusParseFailed;
    }
    if (combined.apiFailureCount > 0) {
        return AgentWakeIOReportTemperatureStatusUnavailable;
    }
    if (combined.sampleCount > 0) {
        reading->celsius = combined.maxCelsius;
        return AgentWakeIOReportTemperatureStatusOK;
    }
    return AgentWakeIOReportTemperatureStatusUnsupportedHardware;
}
