# KindleRewriter ROM Configuration
# Packages to REMOVE from the default LineageOS build
# These are stripped to create a minimal, reading-focused device

# ---- Google / GApps (should not be present without GApps, but guard anyway) ----
PRODUCT_PACKAGES_REMOVE += \
    Gmail \
    GoogleCamera \
    GoogleContactsSyncAdapter \
    GoogleCalendarSyncAdapter \
    GooglePartnerSetup \
    GoogleServicesFramework \
    Phonesky \
    PrebuiltGmsCore \
    YouTube \
    YouTubeMusic \
    Maps \
    Chrome \
    Drive \
    Photos \
    PlayGames

# ---- LineageOS apps we don't need on a reading device ----
PRODUCT_PACKAGES_REMOVE += \
    Dialer \
    Contacts \
    ContactsProvider \
    TeleService \
    Telecomm \
    Phone \
    PhoneProvider \
    Stk \
    CallLogBackup \
    CellBroadcastReceiver \
    EmergencyInfo \
    CarrierConfig

# ---- Media / Entertainment ----
PRODUCT_PACKAGES_REMOVE += \
    Eleven \
    AudioFX \
    Camera2 \
    Gallery2 \
    SnapdragonCamera \
    Snap \
    SoundRecorder \
    VideoEditor \
    ScreenRecorder \
    Recorder

# ---- Communication (no SIM, no phone) ----
PRODUCT_PACKAGES_REMOVE += \
    Messaging \
    messaging \
    Email \
    Exchange2

# ---- Unnecessary system apps ----
PRODUCT_PACKAGES_REMOVE += \
    Calendar \
    CalendarProvider \
    DeskClock \
    Calculator \
    Weather \
    Trebuchet \
    Launcher3 \
    Launcher3QuickStep \
    QuickSearchBox \
    LiveWallpapers \
    LiveWallpapersPicker \
    HoloSpiralWallpaper \
    MagicSmokeWallpapers \
    NoiseField \
    PhaseBeam \
    VisualizationWallpapers \
    WallpaperCropper \
    PrintSpooler \
    PrintRecommendationService \
    NfcNci \
    Tag \
    SecureElement

# ---- Development / Debug (strip for production) ----
PRODUCT_PACKAGES_REMOVE += \
    Development \
    Terminal
