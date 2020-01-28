#!/usr/bin/env python
import glob
import re
import os
import struct
import subprocess
def gcov_src2line2hits(gcno_paths, prefix_filter="/", cwd_fallback="."):
    src2line2hits = {}
    cwd2gcnos = {}
    for gcno in gcno_paths:
        if gcno:
            cwd2gcnos.setdefault(gcno_cwd(gcno, cwd_fallback), set()).add(os.path.abspath(gcno))

    gcov_cmd = ["gcov"] # configurable? or maybe based on .gcno metadata?

    gcov_supports_stdout = os.system(' '.join(gcov_cmd) + " --help 2>/dev/null| grep -- --stdout &>/dev/null") == 0

    for cwd, gcnos in cwd2gcnos.items():
        if gcov_supports_stdout:
            cmd = gcov_cmd + ["--stdout"] + list(gcnos)
            with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, cwd=cwd) as proc:
                gcov_output_parser(proc, cwd, src2line2hits, os.path.abspath(prefix_filter))
        else:
            subprocess.call(gcov_cmd + ["-p"] + list(gcnos), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            gcovs = glob.glob(cwd+"/*.gcov")
            with subprocess.Popen(["cat"] + gcovs, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) as proc:
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

def gcno_cwd(gcno_path, fallback="."):
    with open(gcno_path, "rb") as f:
        f.seek(4)
        version = gcno_read_uint32(f)
        if (version < 0x41393100): # GCC 9.1.0
            return os.path.abspath(fallback)
        f.seek(4, 1)
        return gcno_read_str(f)

def gcno_absolute_path(cwd, path):
    return os.path.abspath(path if path[0] == "/" else cwd + "/" + path)

def gcno_read_uint32(gcno_file):
    data = gcno_file.read(4)
    return struct.unpack("I", data)[0] if len(data) == 4 else 0

def gcno_read_str(gcno_file):
    strlen_in_word = gcno_read_uint32(gcno_file)
    return gcno_file.read(strlen_in_word*4).decode("UTF-8", "ignore").rstrip("\x00")
