#!/usr/bin/env python3
# Writes the public headers of WebKit.framework for macOS into a directory, as
# WebKit's Xcode build installs them:
#
# - the headers of the WebKit target's Headers phase that are Public;
# - the WebKitLegacy and WebCore headers that the "Migrate WebCore and
#   WebKitLegacy Headers" phase copies into WebKit's public headers on macOS
#   (MigratedHeaders-input.xcfilelist and MigratedHeaders-output.xcfilelist);
#
# each passed through WebKit's Scripts/postprocess-header-rule with the settings
# of a macOS build, which is what rewrites <WebKitLegacy/...> to <WebKit/...>
# and resolves the availability macros. Darling's SDK uses the result
# (darling/include/WebKit); run this again when WebKit is updated. The headers
# have the names of the macOS SDK's; unlike some of the SDK's, they keep their
# TARGET_OS_IPHONE blocks, which leave out the same declarations on macOS.
#
#   snapshot-webkit-headers.py <WebKit source root> <output directory> <macOS version>
#
# <macOS version> is the release the WebKit sources belong to; the rule writes
# it where a header says that an API is new in the coming release.

import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


def xcode_public_headers(project, target):
    output = subprocess.run(
        [sys.executable, os.path.join(HERE, "xcode-headers.py"), project, target],
        check=True, capture_output=True, text=True).stdout
    return [line.split(" ", 1)[1] for line in output.splitlines() if line.startswith("Public ")]


def xcfilelist(path):
    with open(path) as f:
        return [line.strip() for line in f if line.strip() and not line.startswith("#")]


def find_header(roots, name):
    for root in roots:
        for directory, _, files in os.walk(root):
            if name in files:
                return os.path.join(directory, name)
    sys.exit(f"error: no source file for the header {name}")


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    source_root, output, macos_version = sys.argv[1:]
    webkit = os.path.join(source_root, "Source", "WebKit")
    rule = os.path.join(webkit, "Scripts", "postprocess-header-rule")

    # (path of the input, as the rule sees it; name in WebKit.framework/Headers)
    headers = []
    project_dir = webkit
    for path in xcode_public_headers(os.path.join(webkit, "WebKit.xcodeproj", "project.pbxproj"), "WebKit"):
        headers.append((os.path.join(project_dir, path), os.path.basename(path)))

    # The rule recognizes migrated headers by the framework in their path, so
    # they are staged under WebKitLegacy.framework and WebCore.framework.
    staging = tempfile.mkdtemp()
    try:
        roots = {
            "$(WEBKITLEGACY_PRIVATE_HEADERS_DIR)": ("WebKitLegacy", [os.path.join(source_root, "Source", "WebKitLegacy")]),
            "$(WEBCORE_PRIVATE_HEADERS_DIR)": ("WebCore", [os.path.join(source_root, "Source", "WebCore")]),
        }
        public_dirs = ("$(TARGET_BUILD_DIR)/$(PUBLIC_HEADERS_FOLDER_PATH)",
                       "$(TARGET_BUILD_DIR)/$(WK_MAC_PUBLIC_IOS_PRIVATE_HEADERS_DIR)")
        inputs = xcfilelist(os.path.join(webkit, "MigratedHeaders-input.xcfilelist"))
        outputs = xcfilelist(os.path.join(webkit, "MigratedHeaders-output.xcfilelist"))
        for input_path, output_path in zip(inputs, outputs):
            output_dir, output_name = output_path.rsplit("/", 1)
            if output_dir not in public_dirs:
                continue
            input_dir, input_name = input_path.rsplit("/", 1)
            framework, search = roots[input_dir]
            # (WebKitLegacy's umbrella header WebKit.h becomes WebKit's WebKitLegacy.h)
            source = find_header(search, input_name)
            staged_dir = os.path.join(staging, f"{framework}.framework", "PrivateHeaders")
            os.makedirs(staged_dir, exist_ok=True)
            staged = os.path.join(staged_dir, input_name)
            shutil.copyfile(source, staged)
            headers.append((staged, output_name))

        if os.path.isdir(output):
            shutil.rmtree(output)
        os.makedirs(output)
        environment = dict(os.environ,
                           SCRIPT_HEADER_VISIBILITY="public",
                           WK_PLATFORM_NAME="macosx",
                           OSX_VERSION=macos_version,
                           SRCROOT=webkit,
                           BUILT_PRODUCTS_DIR=staging,
                           SDKROOT=staging)
        for path, name in sorted(headers, key=lambda header: header[1]):
            environment.update(INPUT_FILE_PATH=path, INPUT_FILE_NAME=os.path.basename(path),
                               SCRIPT_OUTPUT_FILE_0=os.path.join(output, name))
            subprocess.run(["bash", rule], env=environment, check=True)
    finally:
        shutil.rmtree(staging)


if __name__ == "__main__":
    main()
