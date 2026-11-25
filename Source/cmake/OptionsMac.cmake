# FIXME: These should line up with versions in Configurations/Version.xcconfig.
# See Source/WebKitLegacy/PlatformWin.cmake for how WebKitVersion.h is generated.
set(WEBKIT_MAC_VERSION 615.1.1)
set(MACOSX_FRAMEWORK_BUNDLE_VERSION 615.1.1+)

# DARLING: Darling's SDK is not Apple's internal SDK, but it has some of the
# headers that WTF looks for to detect one (see wtf/PlatformUse.h).
if (DARLING)
    add_definitions(-DUSE_APPLE_INTERNAL_SDK=0)
    # It does have os/lock_private.h, which libpas uses for its locks when
    # it can (pas_lock.h). Without OS_UNFAIR_LOCK_INLINE the header leaves
    # out the inline lock functions and libpas's locks become traps. The
    # Xcode build defines it for every target when the SDK has the header
    # (WK_OS_UNFAIR_LOCK_INLINE_CFLAGS in Configurations/CommonBase.xcconfig).
    add_definitions(-DOS_UNFAIR_LOCK_INLINE=1)
    # WebKit tests whether a double fits an int32 by converting it and
    # comparing (canBeStrictInt32 and canBeInt32 in JavaScriptCore's
    # MathCommon.h, among others). An out of range conversion is undefined, and
    # clang 23 reduces the test to "is integral" for x86_64 and i386 with
    # SSE4.1, so 3e9 became -2^31 in JavaScript. With this option out of range
    # conversions saturate and the comparisons keep their meaning.
    add_compile_options(-fno-strict-float-cast-overflow)
    # There is no Swift compiler for Darling's build. Upstream builds without
    # Swift when it is compiled with the WebKit branch of clang
    # (CLANG_WEBKIT_BRANCH): PAL's and WebCore's CryptoKit code (PALSwift) is
    # left out. Compiler.h's other uses of it only matter before clang 21.
    add_definitions(-DCLANG_WEBKIT_BRANCH=1)
    # follows from ENABLE_MEDIA_SOURCE being off (PlatformEnable.h)
    add_definitions(-DENABLE_COCOA_WEBM_PLAYER=0)
    # Darling has no PassKit (Apple Pay is off, above), and its AVFoundation,
    # CoreMedia and MediaToolbox do not play media (video and audio are off)
    add_definitions(-DHAVE_PASSKIT_FRAMEWORK=0 -DUSE_PASSKIT=0)
    add_definitions(-DUSE_AVFOUNDATION=0 -DUSE_MEDIATOOLBOX=0)
    # AVKit's media controls are for the video and audio elements, which are off
    add_definitions(-DHAVE_AVKIT=0)
    # speech recognition takes its audio from capture, and media streams are off
    add_definitions(-DHAVE_SPEECHRECOGNIZER=0)
    # nor is there capture to ask the user's permission for
    add_definitions(-DHAVE_AVCAPTUREDEVICE=0)
    # the audio components that the UI process hands its other processes are
    # for media playback and Web Audio, which are off
    add_definitions(-DHAVE_AUDIO_COMPONENT_SERVER_REGISTRATIONS=0)
    # Darling's ScreenCaptureKit, Vision, SceneKit and Metal are stubs, and it
    # has no AppleGraphicsControl driver to ask about the GPU
    add_definitions(-DHAVE_SCREEN_CAPTURE_KIT=0 -DHAVE_SC_CONTENT_SHARING_PICKER=0)
    add_definitions(-DHAVE_SHAPE_DETECTION_API_IMPLEMENTATION=0 -DHAVE_SCENEKIT=0)
    add_definitions(-DHAVE_WEBGPU_IMPLEMENTATION=0 -DHAVE_APPLE_GRAPHICS_CONTROL=0)
    # Web push needs a daemon talking to the Apple Push Notification service,
    # which Darling has no client for (ApplePushService)
    add_definitions(-DENABLE_WEB_PUSH_NOTIFICATIONS=0)
    # and declarative web push subscribes through that same daemon
    add_definitions(-DENABLE_DECLARATIVE_WEB_PUSH=0)
    # the text extraction item classes (WKTextExtractionItem and the rest) are
    # written in Swift, which this build does not compile (see above)
    add_definitions(-DHAVE_TEXT_EXTRACTION_ITEM_CLASSES=0)
    # Darling's CoreGraphics has none of the PDF restrictions of Lockdown Mode
    add_definitions(-DHAVE_LOCKDOWN_MODE_PDF_ADDITIONS=0)
    # nor has its CoreText a static registry of the system's fonts to turn off
    add_definitions(-DHAVE_STATIC_FONT_REGISTRY=0)
    # Darling's LaunchServices has no database to hand other processes
    # (LSDatabaseContext), and no PowerLog daemon to query
    add_definitions(-DHAVE_LSDATABASECONTEXT=0 -DHAVE_POWERLOG_TASK_MODE_QUERY=0)
    # its CFNetwork, on libcurl, keeps no HTTP alternative services
    add_definitions(-DHAVE_ALTERNATIVE_SERVICE=0)
    # there is no accessibility settings daemon to tell the processes of changes
    add_definitions(-DHAVE_UPDATE_WEB_ACCESSIBILITY_SETTINGS=0)
    # Darling's sandbox enforces nothing, so it has no state flags to set,
    # and its XPC records no reason for an invalidated connection
    add_definitions(-DHAVE_SANDBOX_STATE_FLAGS=0 -DHAVE_XPC_CONNECTION_COPY_INVALIDATION_REASON=0)
    # nor are its preferences served by a daemon that a process could bypass
    add_definitions(-DENABLE_CFPREFS_DIRECT_MODE=0)
    # its events carry no IOHID events, which momentum scrolling is read from
    add_definitions(-DENABLE_MOMENTUM_EVENT_DISPATCHER=0)
    # and it has no AuthKit or AppSSO for single sign-on
    add_definitions(-DHAVE_APP_SSO=0)
    # Darling has no FontParser; its CoreText reads web font data itself
    add_definitions(-DHAVE_FONT_PARSER=0)
    # Darling's CoreImage does not render; WebCore applies the filters itself
    add_definitions(-DUSE_CORE_IMAGE=0)
    # Darling's Accelerate has only part of vImage and vDSP; WebCore has its own
    # code for the rest, as on other ports
    add_definitions(-DUSE_ACCELERATE=0)
    # Darling has no Touch Bar (no hardware, and AppKit has only some of its classes)
    add_definitions(-DHAVE_TOUCH_BAR=0)
    # image analysis (Live Text) needs VisionKit, which Darling has only as a stub,
    # and text recognition in images needs Vision, a stub too
    add_definitions(-DENABLE_IMAGE_ANALYSIS=0 -DENABLE_IMAGE_ANALYSIS_ENHANCEMENTS=0 -DHAVE_VISION=0)
    # QR codes in context-menu images are read with Vision too
    add_definitions(-DENABLE_CONTEXT_MENU_QR_CODE_DETECTION=0)
    # Darling's QuickLookUI has no preview panel to show images in
    add_definitions(-DHAVE_QUICKLOOK_PREVIEW_ITEM_DATA_PROVIDER=0)
    # Darling's Contacts and ContactsUI have no contact picker (or contacts) behind them
    add_definitions(-DHAVE_CONTACTSUI=0 -DHAVE_CONTACTS=0)
    # the test DNS resolver of the network process needs Network's privacy
    # contexts, which Darling's libnetwork does not have
    add_definitions(-DENABLE_DNS_SERVER_FOR_TESTING_IN_NETWORKING_PROCESS=0)
    # Darling's PDFKit is a stub; PDF images are drawn with CoreGraphics, as on iOS.
    # The PDF viewers (WebKit's plugins and WebKitLegacy's PDF view) are built
    # on PDFKit, so they are left out and PDF documents are not shown inline.
    add_definitions(-DUSE_PDFKIT_FOR_PDFDOCUMENTIMAGE=0 -DHAVE_PDFKIT=0)
    add_definitions(-DENABLE_LEGACY_PDFKIT_PLUGIN=0 -DENABLE_UNIFIED_PDF=0 -DENABLE_PDF_PLUGIN=0)
    # the Opus, Vorbis and VP9 helpers are for media playback and WebRTC (off),
    # and need libwebrtc's codecs
    add_definitions(-DENABLE_OPUS=0 -DENABLE_VORBIS=0 -DENABLE_VP9=0)
    # Apple Pay is off
    add_definitions(-DENABLE_APPLE_PAY_AMS_UI=0)
    # audio routing arbitration, asset readers, content key sessions and the
    # video range override are AVFoundation's, whose media support is off
    add_definitions(-DENABLE_ROUTING_ARBITRATION=0 -DHAVE_AVAUDIO_ROUTING_ARBITER=0)
    add_definitions(-DHAVE_AVASSETREADER=0 -DHAVE_AVCONTENTKEYSESSION=0 -DHAVE_AVPLAYER_VIDEORANGEOVERRIDE=0)
    # Darling has no Accessibility framework (custom accessibility content, charts)
    add_definitions(-DHAVE_ACCESSIBILITY_FRAMEWORK=0)
    # Darling has no app links (universal links opened in the app that claims
    # them), and its windows cannot be clipped to a shape, which only the
    # fullscreen animation of WebKitLegacy asks for
    add_definitions(-DHAVE_APP_LINKS=0 -DHAVE_CGS_WINDOW_CLIP_SHAPE=0)
    # MediaAccessibility gives the caption preferences of video text tracks;
    # video is off, and WebCore's caption preferences with it
    add_definitions(-DHAVE_MEDIA_ACCESSIBILITY_FRAMEWORK=0)
    # WebKit checks that each preference's default matches its status (a
    # mature feature is on), which only holds with Apple's feature set: the
    # features Darling turns off keep their status. Other ports skip the check
    # too (wtf/PlatformEnable.h), as the status cannot depend on the platform.
    add_definitions(-DENABLE_FEATURE_DEFAULT_VALIDATION=0)
endif ()

WEBKIT_OPTION_BEGIN()
# Private options shared with other WebKit ports. Add options here only if
# we need a value different from the default defined in WebKitFeatures.cmake.

# FIXME: https://bugs.webkit.org/show_bug.cgi?id=231776
# WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_API_TESTS PRIVATE ON)

# DARLING: on, as in the Xcode build; the Mac accessibility code assumes it
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_ACCESSIBILITY_ISOLATED_TREE PRIVATE ON)
# DARLING: on, as in the Xcode build; the Cocoa canvas code assumes it
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_OFFSCREEN_CANVAS PRIVATE ON)
# DARLING: on, as wtf/PlatformEnableCocoa.h has them for the Xcode build of
# the Mac. CMake's own defaults (WebKitFeatures.cmake) are off and reach the
# code through cmakeconfig.h, which comes first; the Cocoa code assumes the
# Xcode values (WebDriver's key type, the public WKWebExtension API).
foreach (_darling_on IN ITEMS
        ENABLE_DEVICE_ORIENTATION ENABLE_NAVIGATOR_STANDALONE ENABLE_OFFSCREEN_CANVAS_IN_WORKERS
        ENABLE_REFTRACKER ENABLE_WEBDRIVER_BIDI ENABLE_WEBDRIVER_KEYBOARD_GRAPHEME_CLUSTERS
        ENABLE_WK_WEB_EXTENSIONS)
    WEBKIT_OPTION_DEFAULT_PORT_VALUE(${_darling_on} PRIVATE ON)
endforeach ()
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_APPLE_PAY PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_APPLICATION_MANIFEST PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_ASYNC_SCROLLING PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_ATTACHMENT_ELEMENT PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_AVF_CAPTIONS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_CACHE_PARTITIONING PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_CONTENT_EXTENSIONS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_CONTENT_FILTERING PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_CURSOR_VISIBILITY PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_DARK_MODE_CSS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_DATACUE_VALUE PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_DRAG_SUPPORT PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_ENCRYPTED_MEDIA PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_EXPERIMENTAL_FEATURES PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_GAMEPAD PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_GPU_PROCESS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_INSPECTOR_ALTERNATE_DISPATCHERS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_INSPECTOR_EXTENSIONS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_INSPECTOR_TELEMETRY PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_LEGACY_CUSTOM_PROTOCOL_MANAGER PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_LEGACY_ENCRYPTED_MEDIA PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_MEDIA_SOURCE PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_MEDIA_STREAM PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_MEMORY_SAMPLER PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_MOUSE_CURSOR_SCALE PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_PAYMENT_REQUEST PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_PDFKIT_PLUGIN PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_PERIODIC_MEMORY_MONITOR PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_PICTURE_IN_PICTURE_API PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_POINTER_LOCK PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_RESOURCE_USAGE PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_SANDBOX_EXTENSIONS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_SERVICE_CONTROLS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_SHAREABLE_RESOURCE PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_SPEECH_SYNTHESIS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_TELEPHONE_NUMBER_DETECTION PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_TEXT_AUTOSIZING PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_VARIATION_FONTS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_VIDEO_PRESENTATION_MODE PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_WEBDRIVER_KEYBOARD_INTERACTIONS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_WEBDRIVER_MOUSE_INTERACTIONS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_WEBDRIVER_WHEEL_INTERACTIONS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_WEBXR PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_WEB_API_STATISTICS PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_WEB_AUTHN PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_WEB_RTC PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(ENABLE_WIRELESS_PLAYBACK_TARGET PRIVATE ON)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(USE_AVIF PRIVATE OFF)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(USE_JPEGXL PRIVATE OFF)
# DARLING: colour management and WOFF2 fonts come from CoreGraphics and
# CoreText on the Mac, as in the Xcode build, not from lcms2 and libwoff2.
WEBKIT_OPTION_DEFAULT_PORT_VALUE(USE_LCMS PRIVATE OFF)
WEBKIT_OPTION_DEFAULT_PORT_VALUE(USE_WOFF2 PRIVATE OFF)

# DARLING: the features Darling's WebKit is built without. Media playback,
# capture and the other features below need the media frameworks
# (AVFoundation, CoreMedia, VideoToolbox) and services Darling does not
# implement yet; WebRTC's libwebrtc needs NASM, WebGL's ANGLE and WebGPU need
# Metal. Content filtering needs NetworkExtension's NEFilterSource, and
# Darling has no NetworkExtension framework. The GPU process is built, as
# WebKit's Cocoa code expects it; whether pages use it is a preference.
if (DARLING)
    foreach (_darling_off IN ITEMS
            ENABLE_APPLE_PAY ENABLE_AVF_CAPTIONS ENABLE_CONTENT_FILTERING ENABLE_DATACUE_VALUE ENABLE_ENCRYPTED_MEDIA
            ENABLE_GAMEPAD ENABLE_LEGACY_ENCRYPTED_MEDIA ENABLE_MEDIA_RECORDER
            ENABLE_MEDIA_SESSION ENABLE_MEDIA_SOURCE ENABLE_MEDIA_STREAM ENABLE_PAYMENT_REQUEST
            ENABLE_PICTURE_IN_PICTURE_API ENABLE_SERVICE_CONTROLS ENABLE_SPEECH_SYNTHESIS
            ENABLE_TELEPHONE_NUMBER_DETECTION ENABLE_VIDEO ENABLE_VIDEO_PRESENTATION_MODE
            ENABLE_WEBGL ENABLE_WEBGPU ENABLE_WEBXR ENABLE_WEB_AUDIO ENABLE_WEB_AUTHN ENABLE_WEB_RTC
            ENABLE_WIRELESS_PLAYBACK_TARGET)
        WEBKIT_OPTION_DEFAULT_PORT_VALUE(${_darling_off} PRIVATE OFF)
    endforeach ()
endif ()

WEBKIT_OPTION_END()

# DARLING: libwebrtc and ANGLE are only needed by WebCore, for WebRTC and WebGL.
if (ENABLE_WEBCORE AND ENABLE_WEB_RTC)
    SET_AND_EXPOSE_TO_BUILD(USE_LIBWEBRTC TRUE)
endif ()

# DARLING: only with WebCore, so that JavaScriptCore can be built alone.
if (ENABLE_WEBCORE)
    set(ENABLE_WEBKIT_LEGACY ON)
    set(ENABLE_WEBKIT ON)
endif ()

set(bmalloc_LIBRARY_TYPE OBJECT)
set(WTF_LIBRARY_TYPE OBJECT)
set(JavaScriptCore_LIBRARY_TYPE SHARED)
set(PAL_LIBRARY_TYPE OBJECT)
set(WebCore_LIBRARY_TYPE SHARED)

if (ENABLE_WEBCORE AND ENABLE_WEBGL)
    set(USE_ANGLE_EGL ON)
endif ()

find_package(ICU 70.1 REQUIRED COMPONENTS data i18n uc)
find_package(LibXml2 2.8.0 REQUIRED)
find_package(LibXslt 1.1.13 REQUIRED)
