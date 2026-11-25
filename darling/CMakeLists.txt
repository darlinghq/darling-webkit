# Darling's build of WebKit.
#
# Darling's build includes this directory (src/CMakeLists.txt) for the jsc and
# webkit components. It does not build WebKit's sources itself: WebKit's own
# CMake build (its Mac port, the top-level CMakeLists.txt of this repository)
# is configured once per slice as an external project, with a toolchain that
# cross-compiles for macOS against Darling's SDK and links against the
# libraries Darling has built. The slices are then joined with lipo and
# installed as the frameworks of /System/Library/Frameworks.
#
# JavaScriptCore is built for every slice of DARLING_ARCHS. WebCore,
# WebKitLegacy and WebKit only exist for the 64-bit slices, as on macOS; they
# are built with the webkit component.

include(ExternalProject)
include(InstallSymlink)

set(WEBKIT_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/..")

# The frameworks' versions, as WebKit's Xcode build gives them: the current
# version is that of the release (Configurations/Version.xcconfig) with the
# prefix of the macOS release in front of the major number, the compatibility
# version is 1.
file(STRINGS "${WEBKIT_SOURCE_DIR}/Configurations/Version.xcconfig" _version_lines
	REGEX "^(MAJOR|MINOR|TINY)_VERSION = [0-9]+;")
foreach (_line IN LISTS _version_lines)
	string(REGEX MATCH "^([A-Z]+)_VERSION = ([0-9]+);" _ "${_line}")
	set(WEBKIT_${CMAKE_MATCH_1}_VERSION ${CMAKE_MATCH_2})
endforeach ()
set(DARLING_WEBKIT_SYSTEM_VERSION_PREFIX 21)
set(DARLING_WEBKIT_CURRENT_VERSION
	"${DARLING_WEBKIT_SYSTEM_VERSION_PREFIX}${WEBKIT_MAJOR_VERSION}.${WEBKIT_MINOR_VERSION}.${WEBKIT_TINY_VERSION}")

# The release of macOS this WebKit belongs to is macOS 26.4 (Darwin 25.4). It
# is built for the oldest one it supports, macOS 14 (WTF's Platform*.h assume
# at least that), so that it leaves out the code for newer APIs than Darling
# provides.
set(DARLING_WEBKIT_DEPLOYMENT_TARGET 14.0)
set(DARLING_WEBKIT_DARWIN_VERSION 25.4.0)

set(DARLING_SDK "${CMAKE_SOURCE_DIR}/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk")
set(DARLING_CCTOOLS "${CMAKE_BINARY_DIR}/src/external/cctools-port/cctools")
set(DARLING_LD64 "${DARLING_CCTOOLS}/ld64/src/${APPLE_TARGET_TRIPLET_PRIMARY}-ld")
set(DARLING_LIBCXX_INCLUDE "${CMAKE_SOURCE_DIR}/src/external/libcxx/include")
set(DARLING_LIBCXXABI_INCLUDE "${CMAKE_SOURCE_DIR}/src/external/libcxxabi/include")
set(DARLING_LINK_ROOT "${CMAKE_CURRENT_BINARY_DIR}/link-root")

find_program(RUBY_EXECUTABLE ruby REQUIRED)
# WebCore's code generators use ERB, which some distributions package apart
# from Ruby (e.g. Arch's ruby-erb).
execute_process(COMMAND ${RUBY_EXECUTABLE} -e "require 'erb'"
	RESULT_VARIABLE _darling_ruby_erb OUTPUT_QUIET ERROR_QUIET)
if (NOT _darling_ruby_erb EQUAL 0)
	message(FATAL_ERROR "${RUBY_EXECUTABLE} cannot load ERB ('require \"erb\"' fails), which WebKit's code generators need. Install your distribution's ERB package (e.g. ruby-erb).")
endif ()
find_program(PERL_EXECUTABLE perl REQUIRED)
find_program(GPERF_EXECUTABLE gperf REQUIRED)
find_program(UNIFDEF_EXECUTABLE unifdef REQUIRED)

# --- The link root -----------------------------------------------------------
#
# Every dynamic library Darling builds, at the path of its install name (see
# scripts/link-root.py). The list of libraries is only complete once all of
# Darling's directories have been configured, so it is written by a call
# deferred to the end of the top-level directory.

set(_link_root_list "${CMAKE_CURRENT_BINARY_DIR}/link-root.list")
set(_link_root_stamp "${CMAKE_CURRENT_BINARY_DIR}/link-root.stamp")
set(_link_root_excluded "")
if (COMPONENT_gui)
	# the real frameworks are built; leave out their stubs
	list(APPEND _link_root_excluded "${CMAKE_BINARY_DIR}/src/frameworks/dev-stubs")
endif ()

add_custom_command(OUTPUT "${_link_root_stamp}"
	COMMAND "${CMAKE_COMMAND}" -E rm -rf "${DARLING_LINK_ROOT}"
	COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/scripts/link-root.py"
		"${DARLING_LINK_ROOT}" "${_link_root_list}" ${_link_root_excluded}
	COMMAND "${CMAKE_COMMAND}" -E touch "${_link_root_stamp}"
	DEPENDS "${_link_root_list}" "${CMAKE_CURRENT_SOURCE_DIR}/scripts/link-root.py"
	COMMENT "Creating the link root of the WebKit build"
	VERBATIM)
add_custom_target(webkit_link_root DEPENDS "${_link_root_stamp}")

# Whether <target> links against one of WebKit's frameworks, directly or
# through the libraries it links against. Such a library is built after WebKit,
# so WebKit cannot link against it.
function(_darling_webkit_uses_product target out)
	set(${out} FALSE PARENT_SCOPE)
	get_property(visited GLOBAL PROPERTY _DARLING_WEBKIT_VISITED)
	if (target IN_LIST visited)
		get_property(users GLOBAL PROPERTY _DARLING_WEBKIT_USERS)
		if (target IN_LIST users)
			set(${out} TRUE PARENT_SCOPE)
		endif ()
		return()
	endif ()
	set_property(GLOBAL APPEND PROPERTY _DARLING_WEBKIT_VISITED ${target})
	get_target_property(product ${target} DARLING_WEBKIT_PRODUCT)
	set(uses ${product})
	if (NOT uses)
		get_target_property(imported ${target} IMPORTED)
		if (NOT imported)
			get_target_property(libraries ${target} LINK_LIBRARIES)
			foreach (library IN LISTS libraries)
				if (TARGET ${library})
					_darling_webkit_uses_product(${library} library_uses)
					if (library_uses)
						set(uses TRUE)
						break()
					endif ()
				endif ()
			endforeach ()
		endif ()
	endif ()
	if (uses)
		set_property(GLOBAL APPEND PROPERTY _DARLING_WEBKIT_USERS ${target})
		set(${out} TRUE PARENT_SCOPE)
	endif ()
endfunction()

function(_darling_webkit_collect_libraries dir out)
	set(result "")
	get_property(targets DIRECTORY "${dir}" PROPERTY BUILDSYSTEM_TARGETS)
	foreach (target IN LISTS targets)
		get_target_property(type ${target} TYPE)
		if (type STREQUAL "SHARED_LIBRARY")
			_darling_webkit_uses_product(${target} uses_webkit)
			if (NOT uses_webkit)
				list(APPEND result ${target})
			endif ()
		endif ()
	endforeach ()
	# fat libraries joined from per-slice builds (darling_lipo IMPORTED SHARED)
	get_property(imported DIRECTORY "${dir}" PROPERTY IMPORTED_TARGETS)
	foreach (target IN LISTS imported)
		# only the global ones are visible here; Darling's are global, the
		# local ones are host libraries found by find_package()
		if (NOT TARGET ${target})
			continue()
		endif ()
		get_target_property(type ${target} TYPE)
		get_target_property(location ${target} IMPORTED_LOCATION)
		# WebKit's own frameworks are products of this build, not inputs to it
		get_target_property(product ${target} DARLING_WEBKIT_PRODUCT)
		if (type STREQUAL "SHARED_LIBRARY" AND location AND NOT product)
			list(APPEND result ${target})
		endif ()
	endforeach ()
	get_property(subdirs DIRECTORY "${dir}" PROPERTY SUBDIRECTORIES)
	foreach (subdir IN LISTS subdirs)
		_darling_webkit_collect_libraries("${subdir}" sub)
		list(APPEND result ${sub})
	endforeach ()
	set(${out} ${result} PARENT_SCOPE)
endfunction()

function(_darling_webkit_write_link_root_list list target)
	_darling_webkit_collect_libraries("${CMAKE_SOURCE_DIR}" libraries)
	set(content "")
	foreach (target IN LISTS libraries)
		string(APPEND content "$<TARGET_FILE:${target}>\n")
	endforeach ()
	file(GENERATE OUTPUT "${list}" CONTENT "${content}")
	add_dependencies(${target} ${libraries})
endfunction()
# The call runs in the scope of the top-level directory, so the arguments are
# expanded now (the EVAL makes them literal in the deferred call).
cmake_language(EVAL CODE "
	cmake_language(DEFER DIRECTORY [[${CMAKE_SOURCE_DIR}]]
		CALL _darling_webkit_write_link_root_list [[${_link_root_list}]] webkit_link_root)")

# --- The slices --------------------------------------------------------------

darling_archs(DARLING_WEBKIT_JSC_ARCHS)
darling_archs(DARLING_WEBKIT_WEBKIT_ARCHS 64BIT_ONLY)

set(_tools
	"${APPLE_TARGET_TRIPLET_PRIMARY}-ld" "${APPLE_TARGET_TRIPLET_PRIMARY}-ar" ranlib
	install_name_tool_host lipo migexe migcom)

set(DARLING_WEBKIT_VERSION_FLAGS
	"-Wl,-current_version,${DARLING_WEBKIT_CURRENT_VERSION} -Wl,-compatibility_version,1")

foreach (arch IN LISTS DARLING_WEBKIT_JSC_ARCHS)
	set(DARLING_WEBKIT_ARCH_FLAGS "")
	set(arch_args "")
	if (arch STREQUAL "i386")
		# JavaScriptCore on i386 is built as Apple built it there: the C API
		# only, running on the portable interpreter. Apple's i386
		# JavaScriptCore registers none of the Objective-C API classes
		# (JSContext, JSValue, ...), as observed on macOS 10.14.4.
		set(DARLING_WEBKIT_ARCH_FLAGS "-DJSC_OBJC_API_ENABLED=0")
		list(APPEND arch_args
			-DENABLE_C_LOOP=ON -DENABLE_JIT=OFF -DENABLE_DFG_JIT=OFF -DENABLE_FTL_JIT=OFF
			-DENABLE_WEBASSEMBLY=OFF -DENABLE_SAMPLING_PROFILER=OFF)
	endif ()

	set(toolchain "${CMAKE_CURRENT_BINARY_DIR}/toolchain-${arch}.cmake")
	configure_file(toolchain.cmake.in "${toolchain}" @ONLY)

	set(binary_dir "${CMAKE_CURRENT_BINARY_DIR}/${arch}")
	set(webcore OFF)
	if (COMPONENT_webkit AND arch IN_LIST DARLING_WEBKIT_WEBKIT_ARCHS)
		set(webcore ON)
	endif ()

	# Only the frameworks Darling installs are built, not everything WebKit's
	# build defines (its tools, tests and WebGL's ANGLE when WebCore is off).
	set(targets JavaScriptCore)
	if (webcore)
		# and WebKit's XPC services: its web content, networking and GPU processes
		list(APPEND targets WebCore WebKitLegacy WebKit WebProcess NetworkProcess GPUProcess)
	endif ()
	set(products "")
	foreach (target IN LISTS targets)
		list(APPEND products "${binary_dir}/lib/${target}.framework/Versions/A/${target}")
	endforeach ()
	if (CMAKE_GENERATOR MATCHES "Make")
		# $(MAKE) keeps the build in the jobserver of Darling's make
		set(build_command "$(MAKE)" ${targets})
	else ()
		set(build_command "${CMAKE_COMMAND}" --build "${binary_dir}" --target ${targets})
	endif ()

	ExternalProject_Add(webkit_${arch}
		SOURCE_DIR "${WEBKIT_SOURCE_DIR}"
		BINARY_DIR "${binary_dir}"
		CMAKE_GENERATOR "${CMAKE_GENERATOR}"
		CMAKE_ARGS
			"-DCMAKE_TOOLCHAIN_FILE=${toolchain}"
			-DPORT=Mac
			-DDARLING=ON
			"-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
			-DCMAKE_INSTALL_NAME_DIR=/System/Library/Frameworks
			-DCMAKE_BUILD_WITH_INSTALL_NAME_DIR=ON
			-DENABLE_WEBCORE=${webcore}
			-DENABLE_WEBINSPECTORUI=OFF
			-DENABLE_TOOLS=OFF
			-DENABLE_API_TESTS=OFF
			-DUSE_SYSTEM_UNIFDEF=ON
			"-DRUBY_EXECUTABLE=${RUBY_EXECUTABLE}"
			"-DPERL_EXECUTABLE=${PERL_EXECUTABLE}"
			"-DGPERF_EXECUTABLE=${GPERF_EXECUTABLE}"
			"-DUNIFDEF_EXECUTABLE=${UNIFDEF_EXECUTABLE}"
			"-DPython_EXECUTABLE=${Python3_EXECUTABLE}"
			"-DICU_INCLUDE_DIR=${WEBKIT_SOURCE_DIR}/Source/WTF/icu"
			"-DICU_UC_LIBRARY_RELEASE=${DARLING_LINK_ROOT}/usr/lib/libicucore.dylib"
			"-DICU_I18N_LIBRARY_RELEASE=${DARLING_LINK_ROOT}/usr/lib/libicucore.dylib"
			"-DICU_DATA_LIBRARY_RELEASE=${DARLING_LINK_ROOT}/usr/lib/libicucore.dylib"
			"-DREADLINE_LIBRARY=${DARLING_LINK_ROOT}/usr/lib/libedit.dylib"
			"-DMIG_EXECUTABLE=${CMAKE_BINARY_DIR}/build-mig"
			"-DMIG_FLAGS=-arch ${arch} -target ${arch}-apple-macos${DARLING_WEBKIT_DEPLOYMENT_TARGET} -isysroot ${DARLING_SDK}"
			${arch_args}
		BUILD_COMMAND ${build_command}
		BUILD_ALWAYS TRUE
		INSTALL_COMMAND ""
		BUILD_BYPRODUCTS ${products}
		DEPENDS webkit_link_root ${_tools}
	)
endforeach ()

# --- Joining the slices and installing --------------------------------------

# darling_webkit_framework(<name> <archs> [PRIVATE] [IN <umbrella>])
#
# Joins the slices of framework <name> into one file and installs the framework
# the way add_framework() installs Darling's own. With IN, the framework is
# installed inside the bundle of framework <umbrella>, in its
# Versions/A/Frameworks. <name> is then an imported library, located at the
# joined file, that Darling's other targets link against as they would against
# a framework of add_framework().
function(darling_webkit_framework name archs)
	cmake_parse_arguments(FW "PRIVATE" "IN" "" ${ARGN})
	set(slices "")
	set(deps "")
	foreach (arch IN LISTS archs)
		list(APPEND slices "${CMAKE_CURRENT_BINARY_DIR}/${arch}/lib/${name}.framework/Versions/A/${name}")
		list(APPEND deps webkit_${arch})
	endforeach ()
	set(fat "${CMAKE_CURRENT_BINARY_DIR}/fat/${name}")
	# The output is a stamp with the joined file as a byproduct, as in
	# darling_lipo(): a target that links against the imported library depends
	# on its file, and CMake would drop a rule that had that file as its OUTPUT.
	set(stamp "${fat}.lipo-stamp")
	add_custom_command(OUTPUT "${stamp}"
		BYPRODUCTS "${fat}"
		COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/fat"
		COMMAND "${DARLING_CCTOOLS}/misc/lipo" -create ${slices} -output "${fat}"
		COMMAND "${CMAKE_COMMAND}" -E touch "${stamp}"
		DEPENDS ${slices} ${deps} lipo
		COMMENT "Running lipo to create ${name}"
		VERBATIM)
	add_custom_target(${name}_fat ALL DEPENDS "${stamp}")
	add_library(${name} SHARED IMPORTED GLOBAL)
	set_target_properties(${name} PROPERTIES
		IMPORTED_LOCATION "${fat}"
		DARLING_WEBKIT_PRODUCT TRUE)
	add_dependencies(${name} ${name}_fat)

	if (FW_PRIVATE)
		set(root "/System/Library/PrivateFrameworks")
	else ()
		set(root "/System/Library/Frameworks")
	endif ()
	if (FW_IN)
		set(root "${root}/${FW_IN}.framework/Versions/A/Frameworks")
		# <umbrella> re-exports this framework, so the linker looks for it at its
		# install name when a target links against <umbrella>; point that name
		# at the joined file.
		set(map "LINKER:-dylib_file,${root}/${name}.framework/Versions/A/${name}:${fat}")
		set_property(TARGET ${name} APPEND PROPERTY INTERFACE_LINK_OPTIONS "${map}")
		set_property(TARGET ${FW_IN} APPEND PROPERTY INTERFACE_LINK_OPTIONS "${map}")
		add_dependencies(${FW_IN} ${name}_fat)
	endif ()
	set(dir "libexec/darling${root}/${name}.framework")
	install(PROGRAMS "${fat}" DESTINATION "${dir}/Versions/A")
	list(GET archs 0 first)
	install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${first}/lib/${name}.framework/Versions/A/Resources"
		DESTINATION "${dir}/Versions/A" OPTIONAL)
	InstallSymlink(A "${CMAKE_INSTALL_PREFIX}/${dir}/Versions/Current")
	InstallSymlink("Versions/Current/${name}" "${CMAKE_INSTALL_PREFIX}/${dir}/${name}")
	InstallSymlink("Versions/Current/Resources" "${CMAKE_INSTALL_PREFIX}/${dir}/Resources")
endfunction()

darling_webkit_framework(JavaScriptCore "${DARLING_WEBKIT_JSC_ARCHS}")

generate_sdk_framework(JavaScriptCore
	VERSION A
	HEADER "include/JavaScriptCore"
)

# darling_webkit_resources(<name> <project> [IN <umbrella>] [EXTRA <destination> <source> ...])
#
# Installs the resources of framework <name> that its Xcode project
# (Source/<project>/<project>.xcodeproj) copies from the source tree, listed by
# scripts/xcode-resources.py, and the EXTRA pairs that a script phase of the
# project makes (paths relative to Source/<project>). Left out are interface
# files and asset catalogs, which need Apple's compilers, and PDF.js, which
# this build doesn't enable (ENABLE_PDFJS).
function(darling_webkit_resources name project)
	cmake_parse_arguments(RES "" "IN" "EXTRA" ${ARGN})
	set(source "${CMAKE_CURRENT_SOURCE_DIR}/../Source/${project}")
	set(root "/System/Library/Frameworks")
	if (RES_IN)
		set(root "${root}/${RES_IN}.framework/Versions/A/Frameworks")
	endif ()
	set(resources "libexec/darling${root}/${name}.framework/Versions/A/Resources")
	execute_process(
		COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/scripts/xcode-resources.py"
			"${source}/${project}.xcodeproj/project.pbxproj" "${name}"
		OUTPUT_VARIABLE listing
		RESULT_VARIABLE result)
	if (NOT result EQUAL 0)
		message(FATAL_ERROR "xcode-resources.py failed for ${name}")
	endif ()
	set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
		"${source}/${project}.xcodeproj/project.pbxproj")
	string(REPLACE "\n" ";" lines "${listing}")
	foreach (line IN LISTS lines)
		if (line STREQUAL "")
			continue()
		endif ()
		# "<destination> <path>"; neither has spaces in WebKit's projects
		string(REPLACE " " ";" pair "${line}")
		list(GET pair 0 destination)
		list(GET pair 1 path)
		darling_webkit_install_resource("${resources}" "${source}" "${destination}" "${path}")
	endforeach ()
	list(LENGTH RES_EXTRA extras)
	if (extras GREATER 0)
		math(EXPR last "${extras} - 1")
		foreach (i RANGE 0 ${last} 2)
			math(EXPR j "${i} + 1")
			list(GET RES_EXTRA ${i} destination)
			list(GET RES_EXTRA ${j} path)
			darling_webkit_install_resource("${resources}" "${source}" "${destination}" "${path}")
		endforeach ()
	endif ()
endfunction()

function(darling_webkit_install_resource resources source destination path)
	if (destination MATCHES "^pdfjs/" OR path MATCHES "\\.(xib|xcassets)$")
		return()
	endif ()
	get_filename_component(directory "${destination}" DIRECTORY)
	get_filename_component(file "${destination}" NAME)
	if (IS_DIRECTORY "${source}/${path}")
		install(DIRECTORY "${source}/${path}/" DESTINATION "${resources}/${destination}")
	elseif (EXISTS "${source}/${path}")
		install(FILES "${source}/${path}" DESTINATION "${resources}/${directory}" RENAME "${file}")
	endif ()
endfunction()

# darling_webkit_xpc_service(<identifier> <archs>)
#
# Joins the slices of one of WebKit's XPC services (its executable is named
# like the service) and installs the service bundle in WebKit's XPCServices,
# where a process that has loaded WebKit finds it.
function(darling_webkit_xpc_service identifier archs)
	set(slices "")
	set(deps "")
	foreach (arch IN LISTS archs)
		list(APPEND slices "${CMAKE_CURRENT_BINARY_DIR}/${arch}/lib/WebKit.framework/Versions/A/XPCServices/${identifier}.xpc/Contents/MacOS/${identifier}")
		list(APPEND deps webkit_${arch})
	endforeach ()
	set(fat "${CMAKE_CURRENT_BINARY_DIR}/fat/${identifier}")
	set(stamp "${fat}.lipo-stamp")
	add_custom_command(OUTPUT "${stamp}"
		BYPRODUCTS "${fat}"
		COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/fat"
		COMMAND "${DARLING_CCTOOLS}/misc/lipo" -create ${slices} -output "${fat}"
		COMMAND "${CMAKE_COMMAND}" -E touch "${stamp}"
		DEPENDS ${slices} ${deps} lipo
		COMMENT "Running lipo to create ${identifier}"
		VERBATIM)
	add_custom_target(${identifier}_fat ALL DEPENDS "${stamp}")

	list(GET archs 0 first)
	set(contents "libexec/darling/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/${identifier}.xpc/Contents")
	install(PROGRAMS "${fat}" DESTINATION "${contents}/MacOS")
	install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${first}/lib/WebKit.framework/Versions/A/XPCServices/${identifier}.xpc/Contents/Info.plist"
		DESTINATION "${contents}")
endfunction()

# WebCore and WebKitLegacy are frameworks inside WebKit's bundle, as on macOS
# (their install names are set in WebKit's Source/*/PlatformMac.cmake), and
# only exist for the 64-bit slices.
if (COMPONENT_webkit)
	darling_webkit_framework(WebKit "${DARLING_WEBKIT_WEBKIT_ARCHS}")
	darling_webkit_framework(WebCore "${DARLING_WEBKIT_WEBKIT_ARCHS}" IN WebKit)
	darling_webkit_framework(WebKitLegacy "${DARLING_WEBKIT_WEBKIT_ARCHS}" IN WebKit)
	# WebCore's Localizable.strings is copied by a script phase, which appends
	# strings from Apple's internal SDK when it has them.
	darling_webkit_resources(WebCore WebCore IN WebKit
		EXTRA en.lproj/Localizable.strings en.lproj/Localizable.strings)
	darling_webkit_resources(WebKitLegacy WebKitLegacy IN WebKit)
	darling_webkit_xpc_service(com.apple.WebKit.WebContent "${DARLING_WEBKIT_WEBKIT_ARCHS}")
	darling_webkit_xpc_service(com.apple.WebKit.Networking "${DARLING_WEBKIT_WEBKIT_ARCHS}")
	darling_webkit_xpc_service(com.apple.WebKit.GPU "${DARLING_WEBKIT_WEBKIT_ARCHS}")
	InstallSymlink("Versions/Current/XPCServices"
		"${CMAKE_INSTALL_PREFIX}/libexec/darling/System/Library/Frameworks/WebKit.framework/XPCServices")
	InstallSymlink("Versions/Current/Frameworks"
		"${CMAKE_INSTALL_PREFIX}/libexec/darling/System/Library/Frameworks/WebKit.framework/Frameworks")

	generate_sdk_framework(WebKit
		VERSION A
		HEADER "include/WebKit"
	)
endif ()
