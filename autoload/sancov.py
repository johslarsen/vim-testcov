#!/usr/bin/env python
import json
import os
import re
import subprocess
def sancov_src2line2hits(sancov_paths):
    src2line2hits = {}

    bin2sancov = {}
    re_bin = re.compile('(\\.[0-9]+)?\\.sancov$')
    for sancov_path in sancov_paths:
        if not sancov_path:
            continue
        bin_path = re_bin.sub("", sancov_path)
        if bin_path not in bin2sancov:
            bin2sancov[bin_path] = sancov_path
        else:
            previous = os.stat(bin2sancov[bin_path])
            current = os.stat(sancov_path)
            if current.st_ctime > previous.st_ctime:
                bin2sancov[bin_path] = sancov_path

    for bin_path, sancov_path in bin2sancov.items():
        args = ["sancov", "-symbolize", sancov_path, bin_path]
        with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as proc:
            stdout, stderr = proc.communicate()
            if len(stderr) > 0:
                print(stderr)
            sancov_report_parser(json.loads(stdout), src2line2hits)
    return src2line2hits

def sancov_report_parser(sancov_report, src2line2hits):
    for path, func2point2line_col in sancov_report["point-symbol-info"].items():
        line2hits = src2line2hits[path] = {}
        for _, point2line_col in func2point2line_col.items():
            for _, line_col in point2line_col.items():
                line = line_col.split(":")[0]
                if line != "0":
                    line2hits[line] = line2hits.get(line, 0) + 1
