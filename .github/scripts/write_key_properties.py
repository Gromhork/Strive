"""Writes android/key.properties for the release workflow (see .github/workflows/release.yml).

Gradle (android/app/build.gradle.kts) loads the file with java.util.Properties, which reads
ISO-8859-1, treats backslashes as escapes and drops leading blanks of a value. Every value is
therefore escaped the way Properties.store() does it, so passwords may contain any character.

Usage: KEYSTORE_PASSWORD=... KEY_PASSWORD=... KEY_ALIAS=... python3 write_key_properties.py OUT
"""

import os
import sys


def escape_value(value: str) -> str:
    out = []
    for ch in value:
        code = ord(ch)
        if ch == "\\":
            out.append("\\\\")
        elif ch in " =:#!":
            out.append("\\" + ch)
        elif ch == "\t":
            out.append("\\t")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\f":
            out.append("\\f")
        elif code < 0x20 or code > 0x7E:
            # Java chars are UTF-16 code units; characters outside the BMP become a surrogate pair.
            units = ch.encode("utf-16-be")
            for i in range(0, len(units), 2):
                out.append("\\u%04X" % int.from_bytes(units[i : i + 2], "big"))
        else:
            out.append(ch)
    return "".join(out)


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("usage: write_key_properties.py OUT_FILE")
    entries = [
        ("storePassword", os.environ["KEYSTORE_PASSWORD"]),
        ("keyPassword", os.environ["KEY_PASSWORD"]),
        ("keyAlias", os.environ["KEY_ALIAS"]),
        ("storeFile", "upload-keystore.jks"),
    ]
    with open(sys.argv[1], "w", encoding="ascii", newline="\n") as f:
        for key, value in entries:
            f.write(key + "=" + escape_value(value) + "\n")


if __name__ == "__main__":
    main()
