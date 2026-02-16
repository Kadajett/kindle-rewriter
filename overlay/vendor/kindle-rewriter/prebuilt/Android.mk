LOCAL_PATH := $(call my-dir)

# ---- KOReader ----
# Download the latest ARM Android build from:
#   https://github.com/koreader/koreader/releases
# Place the APK as: prebuilt/KOReader.apk

include $(CLEAR_VARS)
LOCAL_MODULE := KOReader
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_CERTIFICATE := PRESIGNED
LOCAL_SRC_FILES := KOReader.apk
LOCAL_PRIVILEGED_MODULE := false
LOCAL_OVERRIDES_PACKAGES :=
include $(BUILD_PREBUILT)
