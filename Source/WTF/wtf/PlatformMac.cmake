find_library(COCOA_LIBRARY Cocoa)
find_library(COREFOUNDATION_LIBRARY CoreFoundation)
find_library(READLINE_LIBRARY Readline)
find_library(SECURITY_LIBRARY Security)
if (DARLING)
    # DARLING: JavaScriptCore on macOS links Foundation and CoreServices
    # (Metadata), not AppKit (Cocoa), and no line editing library; WTF uses
    # no AppKit API. Readline is only for the jsc shell's prompt.
    find_library(FOUNDATION_LIBRARY Foundation)
    find_library(CORESERVICES_LIBRARY CoreServices)
    list(APPEND WTF_LIBRARIES
        ${COREFOUNDATION_LIBRARY}
        ${CORESERVICES_LIBRARY}
        ${FOUNDATION_LIBRARY}
        ${SECURITY_LIBRARY}
    )
else ()
list(APPEND WTF_LIBRARIES
    ${COREFOUNDATION_LIBRARY}
    ${COCOA_LIBRARY}
    ${READLINE_LIBRARY}
    ${SECURITY_LIBRARY}
)
endif ()

list(APPEND WTF_SOURCES
    BlockObjCExceptions.mm
    ProcessPrivilege.cpp
    TranslatedProcess.cpp

    cf/CFURLExtras.cpp
    cf/FileSystemCF.cpp
    cf/LanguageCF.cpp
    cf/RunLoopCF.cpp
    cf/SchedulePairCF.cpp
    cf/URLCF.cpp

    cocoa/AutodrainedPool.cpp
    cocoa/CrashReporter.cpp
    cocoa/Entitlements.mm
    cocoa/FileSystemCocoa.mm
    cocoa/LanguageCocoa.mm
    cocoa/LoggingCocoa.mm
    cocoa/MachSendRight.cpp
    cocoa/MainThreadCocoa.mm
    cocoa/MemoryFootprintCocoa.cpp
    cocoa/MemoryPressureHandlerCocoa.mm
    cocoa/NSURLExtras.mm
    cocoa/ResourceUsageCocoa.cpp
    cocoa/RuntimeApplicationChecksCocoa.mm
    cocoa/AuditToken.mm
    cocoa/SpanCocoa.mm
    cocoa/UUIDCocoa.mm
    text/cocoa/TextStreamCocoa.mm
    ObjCRuntimeExtras.mm
    PlatformRegisters.cpp
    PtrTag.cpp
    SizeLimits.cpp
    cocoa/SchedulePairCocoa.mm
    cocoa/SystemTracingCocoa.cpp
    cocoa/URLCocoa.mm
    cocoa/WorkQueueCocoa.cpp

    darwin/LibraryPathDiagnostics.mm

    mac/FileSystemMac.mm

    posix/CPUTimePOSIX.cpp
    posix/FileHandlePOSIX.cpp
    posix/FileSystemPOSIX.cpp
    posix/MappedFileDataPOSIX.cpp
    posix/OSAllocatorPOSIX.cpp
    posix/ThreadingPOSIX.cpp

    text/cf/AtomStringImplCF.cpp
    text/cf/StringCF.cpp
    text/cf/StringImplCF.cpp
    text/cf/StringViewCF.cpp

    text/cocoa/ASCIILiteralCocoa.mm
    text/cocoa/ContextualizedCFString.mm
    text/cocoa/ContextualizedNSString.mm
    text/cocoa/StringCocoa.mm
    text/cocoa/StringImplCocoa.mm
    text/cocoa/StringViewCocoa.mm
    text/cocoa/TextBreakIteratorInternalICUCocoa.cpp
)

list(APPEND WTF_PUBLIC_HEADERS
    cf/CFTypeTraits.h
    cf/CFURLExtras.h
    cf/NotificationCenterCF.h
    cf/TypeCastsCF.h
    cf/VectorCF.h

    cocoa/CrashReporter.h
    cocoa/Entitlements.h
    cocoa/NSURLExtras.h
    cocoa/RuntimeApplicationChecksCocoa.h
    cocoa/SoftLinking.h
    cocoa/TollFreeBridging.h
    cocoa/TypeCastsCocoa.h
    cocoa/VectorCocoa.h

    darwin/OSLogPrintStream.h
    darwin/WeakLinking.h
    darwin/XPCExtras.h

    spi/cf/CFBundleSPI.h
    spi/cf/CFStringSPI.h

    spi/cocoa/CFXPCBridgeSPI.h
    spi/cocoa/CrashReporterClientSPI.h
    spi/cocoa/IOSurfaceSPI.h
    spi/cocoa/MachVMSPI.h
    spi/cocoa/NSLocaleSPI.h
    spi/cocoa/NSObjCRuntimeSPI.h
    spi/cocoa/SecuritySPI.h
    spi/cocoa/objcSPI.h

    spi/darwin/ReasonSPI.h
    spi/darwin/CodeSignSPI.h
    spi/darwin/DataVaultSPI.h
    spi/darwin/OSVariantSPI.h
    spi/darwin/ProcessMemoryFootprint.h
    spi/darwin/SandboxSPI.h
    spi/darwin/XPCSPI.h
    spi/darwin/dyldSPI.h

    spi/mac/MetadataSPI.h

    text/cf/StringConcatenateCF.h
    text/cf/TextBreakIteratorCF.h
)

# DARLING: headers that WTF.xcodeproj installs on macOS and this list lacked.
list(APPEND WTF_PUBLIC_HEADERS
    MachSendRightAnnotated.h
    SequenceLocked.h

    cocoa/AuditToken.h
    cocoa/NSStringExtras.h
    cocoa/SpanCocoa.h

    darwin/LibraryPathDiagnostics.h
    darwin/TypeCastsOSObject.h
    darwin/XPCObjectPtr.h

    posix/SocketPOSIX.h

    spi/cf/CFPrivSPI.h
    spi/cf/CFRunLoopSPI.h

    spi/cocoa/BOMSPI.h
    spi/cocoa/IOReturnSPI.h
    spi/cocoa/IOTypesSPI.h
    spi/cocoa/OSLogSPI.h
    spi/cocoa/XTSPI.h

    spi/darwin/DispatchSPI.h

    text/cf/TextBreakIteratorCFCharacterCluster.h
    text/cf/TextBreakIteratorCFStringTokenizer.h

    text/cocoa/ContextualizedCFString.h
    text/cocoa/ContextualizedNSString.h
)

file(COPY mac/MachExceptions.defs DESTINATION ${WTF_DERIVED_SOURCES_DIR})

# DARLING: the MIG program and the options it needs for the target (Darling
# runs a host build of it with the slice's -arch, -target and -isysroot).
set(MIG_EXECUTABLE mig CACHE STRING "The Mach Interface Generator")
set(MIG_FLAGS "" CACHE STRING "Options for the Mach Interface Generator")
separate_arguments(_wtf_mig_flags UNIX_COMMAND "${MIG_FLAGS}")

add_custom_command(
    OUTPUT
        ${WTF_DERIVED_SOURCES_DIR}/MachExceptionsServer.h
        ${WTF_DERIVED_SOURCES_DIR}/mach_exc.h
        ${WTF_DERIVED_SOURCES_DIR}/mach_excServer.c
        ${WTF_DERIVED_SOURCES_DIR}/mach_excUser.c
    MAIN_DEPENDENCY mac/MachExceptions.defs
    WORKING_DIRECTORY ${WTF_DERIVED_SOURCES_DIR}
    COMMAND ${MIG_EXECUTABLE} ${_wtf_mig_flags} -DMACH_EXC_SERVER_TASKIDTOKEN_STATE -sheader MachExceptionsServer.h MachExceptions.defs
    VERBATIM)
list(APPEND WTF_SOURCES
    ${WTF_DERIVED_SOURCES_DIR}/mach_excServer.c
    ${WTF_DERIVED_SOURCES_DIR}/mach_excUser.c
)
