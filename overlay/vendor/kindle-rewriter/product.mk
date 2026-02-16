# KindleRewriter Product Configuration
# Defines what IS included in our minimal reading-focused ROM

# Pull in the strip list
include vendor/kindle-rewriter/config.mk

# ---- Our custom apps ----
PRODUCT_PACKAGES += \
    KidsLauncher

# ---- Prebuilt apps we bundle ----
PRODUCT_PACKAGES += \
    KOReader

# ---- Essential system apps we keep ----
PRODUCT_PACKAGES += \
    Jelly \
    DocumentsUI \
    Settings \
    SettingsProvider \
    SystemUI \
    PackageInstaller \
    CertInstaller \
    KeyChain \
    DownloadProvider \
    DownloadProviderUi \
    FusedLocation \
    InputDevices \
    ExternalStorageProvider

# ---- Device properties ----
PRODUCT_PROPERTY_OVERRIDES += \
    ro.kindle_rewriter.version=1.0.0 \
    ro.kindle_rewriter.device_purpose=reading \
    ro.setupwizard.mode=DISABLED \
    ro.config.notification_sound=OnTheHunt.ogg \
    ro.config.alarm_alert=Alarm_Classic.ogg

# Disable auto-updates (no Play Store anyway)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.ota.disable=1

# Set our launcher as default
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.default_launcher=org.kindlerewriter.kidslauncher

# Disable unused radios
PRODUCT_PROPERTY_OVERRIDES += \
    ro.radio.noril=yes \
    persist.sys.nfc.off=true

# Keep WiFi enabled by default (for library book downloads)
PRODUCT_PROPERTY_OVERRIDES += \
    wifi.interface=wlan0

# Power saving: reduce animations for battery life on reading device
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.ui.hw=false \
    debug.performance.tuning=1 \
    windowsmgr.max_events_per_sec=60
