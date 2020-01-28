#!/usr/bin/env python
import glob
import re
import os
import struct
import subprocess
def gcov_src2line2hits(gcno_paths, prefix_filter="/"):
    src2line2hits = {}
    cwd2gcnos = {}
    for gcno in gcno_paths:
        if gcno:
            cwd2gcnos.setdefault(gcno_cwd(gcno), set()).add(os.path.abspath(gcno))

    for cwd, gcnos in cwd2gcnos.items():
        with subprocess.Popen(["gcov", "--stdout"] + list(gcnos), stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd) as proc:
            gcov_output_parser(proc, cwd, src2line2hits, os.path.abspath(prefix_filter))
    return src2line2hits

def gcov_output_parser(gcov_pipe, cwd, src2line2hits, prefix_filter="/"):
    line2hits = None
    re_source = re.compile('.*0:Source:(.*)')
    re_tag = re.compile('^[ ]*([#0-9]+)\*?:[ ]*([0-9]+):')
    while True:
        line = gcov_pipe.stdout.readline()
        if not line:
            break
        line = line.decode("UTF-8", "ignore")
        maybe_filename = re_source.match(line)
        if maybe_filename:
            src = gcno_absolute_path(cwd, maybe_filename.group(1))
            line2hits = src2line2hits.setdefault(src, {}) if src.startswith(prefix_filter) else None
            continue
        elif line2hits is None:
            continue
        tag_linenr = re_tag.match(line)
        if tag_linenr:
            tag = tag_linenr.group(1)
            nr = tag_linenr.group(2)
            line2hits[nr] = line2hits.get(nr, 0) + (int(tag) if tag[0] != '#' else 0)

def gcno_cwd(gcno_path):
    with open(gcno_path, "rb") as f:
        f.seek(12)
        return gcno_read_str(f)

def gcno_absolute_path(cwd, path):
    return os.path.abspath(path if path[0] == "/" else cwd + "/" + path)

def gcno_read_uint32(gcno_file):
    data = gcno_file.read(4)
    return struct.unpack("I", data)[0] if len(data) == 4 else 0

def gcno_read_str(gcno_file):
    strlen_in_word = gcno_read_uint32(gcno_file)
    return gcno_file.read(strlen_in_word*4).decode("UTF-8", "ignore").rstrip("\x00")
