#!/usr/bin/env python3
# Lists the headers that an Xcode target installs, as the Xcode project says:
# the files of the target's Headers build phase, one per line, as
#
#   <visibility> <path>
#
# where <visibility> is Public, Private or Project and <path> is relative to
# the directory that holds the .xcodeproj. CMake reads the list to install the
# same framework headers that the Xcode build of the target does.
#
# With --all-project-headers, the project's other headers follow as Project
# headers too: Xcode's project header map finds every header of the project,
# not only the target's. A header whose name was already listed is left out,
# since a lookup by name finds one file.
#
#   xcode-headers.py [--all-project-headers] <project.pbxproj> <target name>

import os
import sys


def parse(text):
    """Parses an old-style (OpenStep) property list, as project.pbxproj is."""
    pos = 0
    length = len(text)

    def skip():
        nonlocal pos
        while pos < length:
            if text[pos].isspace():
                pos += 1
            elif text.startswith("/*", pos):
                pos = text.index("*/", pos) + 2
            elif text.startswith("//", pos):
                pos = text.index("\n", pos)
            else:
                break

    def value():
        nonlocal pos
        skip()
        c = text[pos]
        if c == "{":
            pos += 1
            result = {}
            while True:
                skip()
                if text[pos] == "}":
                    pos += 1
                    return result
                key = value()
                skip()
                assert text[pos] == "=", text[pos - 40:pos + 40]
                pos += 1
                result[key] = value()
                skip()
                assert text[pos] == ";", text[pos - 40:pos + 40]
                pos += 1
        if c == "(":
            pos += 1
            result = []
            while True:
                skip()
                if text[pos] == ")":
                    pos += 1
                    return result
                result.append(value())
                skip()
                if text[pos] == ",":
                    pos += 1
        if c == '"':
            pos += 1
            out = []
            while text[pos] != '"':
                if text[pos] == "\\":
                    pos += 1
                    out.append({"n": "\n", "t": "\t"}.get(text[pos], text[pos]))
                else:
                    out.append(text[pos])
                pos += 1
            pos += 1
            return "".join(out)
        start = pos
        while pos < length and (text[pos].isalnum() or text[pos] in "_$/.-+:"):
            pos += 1
        assert pos > start, text[pos - 40:pos + 40]
        return text[start:pos]

    skip()
    if text.startswith("// !$*UTF8*$!"):
        pos = text.index("\n")
    return value()


def main():
    arguments = sys.argv[1:]
    all_project_headers = "--all-project-headers" in arguments
    if all_project_headers:
        arguments.remove("--all-project-headers")
    project_file, target_name = arguments
    with open(project_file, encoding="utf-8") as f:
        objects = parse(f.read())["objects"]

    # Where each file and group is, from the groups that hold them.
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
        return None  # built products, the SDK and the like

    targets = [obj for obj in objects.values()
               if obj.get("isa") == "PBXNativeTarget" and obj.get("name") == target_name]
    if len(targets) != 1:
        sys.exit("xcode-headers.py: no single target named " + target_name)

    names = set()
    for phase in targets[0]["buildPhases"]:
        if objects[phase].get("isa") != "PBXHeadersBuildPhase":
            continue
        for build_file in objects[phase]["files"]:
            entry = objects[build_file]
            attributes = entry.get("settings", {}).get("ATTRIBUTES", [])
            visibility = "Public" if "Public" in attributes else "Private" if "Private" in attributes else "Project"
            path = path_of(entry["fileRef"])
            if path:
                print(visibility, path)
                names.add(os.path.basename(path))

    if all_project_headers:
        for key in sorted(objects):
            obj = objects[key]
            if obj.get("isa") != "PBXFileReference" or not obj.get("path", "").endswith(".h"):
                continue
            path = path_of(key)
            if not path or os.path.basename(path) in names:
                continue
            names.add(os.path.basename(path))
            print("Project", path)


if __name__ == "__main__":
    main()
