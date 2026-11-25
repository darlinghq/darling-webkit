#!/usr/bin/env python3
# Builds the tree that the WebKit build links against: every dynamic library
# that Darling builds, as a symbolic link at the path of its install name
# (LC_ID_DYLIB), inside the given root. Passed to ld64 with -syslibroot, it
# resolves -framework and -l options and the libraries that they re-export the
# way the installed system does, without installing anything.
#
#   link-root.py <root> <list> [<excluded directory>...]
#
# <list> holds one path per line: the files of Darling's shared library and
# framework targets. Files that do not exist yet (targets the WebKit build does
# not depend on) and files that are not dylibs are skipped. The "firstpass"
# libraries of Darling's circular builds carry the install name of the final
# library and are skipped as well, and so is everything inside the excluded
# directories (Darling's stub frameworks, when it builds the real ones).

import os
import struct
import sys

MH_DYLIB = 6
LC_ID_DYLIB = 0xD
MAGIC_32 = 0xFEEDFACE
MAGIC_64 = 0xFEEDFACF
FAT_MAGIC = 0xCAFEBABE
FAT_MAGIC_64 = 0xCAFEBABF


def install_name_of_slice(data, offset):
    magic = struct.unpack_from("<I", data, offset)[0]
    if magic == MAGIC_32:
        header_size = 28
    elif magic == MAGIC_64:
        header_size = 32
    else:
        return None
    _, _, _, filetype, ncmds, _, _ = struct.unpack_from("<IiiIIII", data, offset)
    if filetype != MH_DYLIB:
        return None
    pos = offset + header_size
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", data, pos)
        if cmd == LC_ID_DYLIB:
            name_offset = struct.unpack_from("<I", data, pos + 8)[0]
            raw = data[pos + name_offset:pos + cmdsize]
            return raw.split(b"\0", 1)[0].decode()
        pos += cmdsize
    return None


def install_name(path):
    with open(path, "rb") as f:
        head = f.read(8)
        if len(head) < 8:
            return None
        magic_be = struct.unpack_from(">I", head)[0]
        f.seek(0)
        if magic_be in (FAT_MAGIC, FAT_MAGIC_64):
            data = f.read()
            nfat = struct.unpack_from(">I", data, 4)[0]
            for i in range(nfat):
                if magic_be == FAT_MAGIC:
                    entry = struct.unpack_from(">iiIII", data, 8 + i * 20)
                else:
                    entry = struct.unpack_from(">iiQQII", data, 8 + i * 32)
                name = install_name_of_slice(data, entry[2])
                if name:
                    return name
            return None
        if struct.unpack_from("<I", head)[0] in (MAGIC_32, MAGIC_64):
            return install_name_of_slice(f.read(), 0)
    return None


def main():
    root, listing = sys.argv[1], sys.argv[2]
    excluded = [os.path.join(os.path.abspath(d), "") for d in sys.argv[3:]]
    with open(listing) as f:
        files = [line.strip() for line in f if line.strip()]
    files = [p for p in files if not any(os.path.abspath(p).startswith(d) for d in excluded)]

    candidates = {}
    for path in files:
        if "firstpass" in os.path.basename(path) or not os.path.isfile(path):
            continue
        name = install_name(path)
        if name:
            candidates.setdefault(name, set()).add(path)

    chosen = {}
    for name, paths in candidates.items():
        if len(paths) > 1:
            # Darling builds some libraries once per slice (Foundation_i386,
            # Foundation_x86_64) and joins the slices with lipo into the file
            # that has the name of the installed library; that one is used.
            paths = {p for p in paths if os.path.basename(p) == os.path.basename(name)}
            if len(paths) != 1:
                sys.exit("link-root.py: several files have the install name %s: %s"
                         % (name, ", ".join(sorted(candidates[name]))))
        chosen[name] = paths.pop()

    for name, path in sorted(chosen.items()):
        link = os.path.join(root, name.lstrip("/"))
        os.makedirs(os.path.dirname(link), exist_ok=True)
        if os.path.islink(link) and os.readlink(link) == path:
            continue
        if os.path.lexists(link):
            os.unlink(link)
        os.symlink(path, link)
        # -framework X and -lx look for the unversioned names
        parts = name.split("/")
        for i, part in enumerate(parts):
            if part.endswith(".framework"):
                framework = part[:-len(".framework")]
                top = os.path.join(root, *parts[1:i + 1], framework)
                if top != link and not os.path.lexists(top):
                    os.symlink(path, top)
                break
        else:
            base = os.path.basename(name)
            if base.startswith("lib") and base.endswith(".dylib"):
                stem = base[:-len(".dylib")].split(".")[0]
                plain = os.path.join(os.path.dirname(link), stem + ".dylib")
                if plain != link and not os.path.lexists(plain):
                    os.symlink(path, plain)


if __name__ == "__main__":
    main()
