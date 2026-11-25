#!/usr/bin/env python3
# Lists the files that an Xcode target copies into its bundle's Resources, as
# the Xcode project says: the files of the target's Resources build phase, one
# per line (and the files its Copy Files phases put into Resources), as
#
#   <destination> <path>
#
# where <destination> is the path inside Resources (a localized file goes to
# its <language>.lproj directory) and <path> is relative to the directory that
# holds the .xcodeproj. Files the build makes rather than the source tree has
# are left out. CMake reads the list to install the same resources that the
# Xcode build of the target does.
#
#   xcode-resources.py <project.pbxproj> <target name>

import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("xcode_headers", os.path.join(HERE, "xcode-headers.py"))
xcode_headers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(xcode_headers)


def main():
    project_file, target_name = sys.argv[1:]
    with open(project_file, encoding="utf-8") as f:
        objects = xcode_headers.parse(f.read())["objects"]

    parents = {}
    for key, obj in objects.items():
        for child in obj.get("children", []):
            parents[child] = key

    def path_of(key):
        obj = objects[key]
        path = obj.get("path", "")
        tree = obj.get("sourceTree", "<group>")
        if tree == "<group>" and key in parents:
            parent = path_of(parents[key])
            return parent + "/" + path if parent and path else parent or path
        if tree in ("<group>", "SOURCE_ROOT"):
            return path
        return None

    targets = [obj for obj in objects.values()
               if obj.get("isa") == "PBXNativeTarget" and obj.get("name") == target_name]
    if len(targets) != 1:
        sys.exit("xcode-resources.py: no single target named " + target_name)

    for phase in targets[0]["buildPhases"]:
        isa = objects[phase].get("isa")
        if isa == "PBXCopyFilesBuildPhase" and objects[phase].get("dstSubfolderSpec") == "7":
            # a Copy Files phase into a directory of Resources
            directory = objects[phase].get("dstPath", "")
            for build_file in objects[phase]["files"]:
                path = path_of(objects[build_file]["fileRef"])
                if path:
                    print(os.path.join(directory, os.path.basename(path)), path)
            continue
        if isa != "PBXResourcesBuildPhase":
            continue
        for build_file in objects[phase]["files"]:
            ref = objects[build_file]["fileRef"]
            if objects[ref].get("isa") == "PBXVariantGroup":
                # one file per language, named <language>.lproj/<name>
                for child in objects[ref]["children"]:
                    path = path_of(child)
                    if path:
                        language = os.path.basename(os.path.dirname(path))
                        print(language + "/" + os.path.basename(path), path)
                continue
            path = path_of(ref)
            if path:
                print(os.path.basename(path), path)


if __name__ == "__main__":
    main()
