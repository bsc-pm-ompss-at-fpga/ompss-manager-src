#!/usr/bin/env python3
#
#------------------------------------------------------------------------#
#    (C) Copyright 2017-2020 Barcelona Supercomputing Center             #
#                            Centro Nacional de Supercomputacion         #
#                                                                        #
#    This file is part of OmpSs@FPGA toolchain.                          #
#                                                                        #
#    This code is free software; you can redistribute it and/or modify   #
#    it under the terms of the GNU General Public License as published   #
#    by the Free Software Foundation; either version 3 of the License,   #
#    or (at your option) any later version.                              #
#                                                                        #
#    OmpSs@FPGA toolchain is distributed in the hope that it will be     #
#    useful, but WITHOUT ANY WARRANTY; without even the implied          #
#    warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    #
#    See the GNU General Public License for more details.                #
#                                                                        #
#    You should have received a copy of the GNU General Public License   #
#    along with this code. If not, see <www.gnu.org/licenses/>.          #
#------------------------------------------------------------------------#

import os
import sys
import re
import subprocess
import argparse
from distutils import spawn

class Logger(object):
    def __init__(self):
        self.terminal = sys.stdout
        self.log = open('run_tests.log', 'w+')
        self.re_color = re.compile(r'\033\[[0,1][0-9,;]*m')

    def write(self, message):
        self.terminal.write(message)
        self.log.write(self.re_color.sub('', message))
        self.log.flush()

    def writeVerbose(self, message):
        if args.verbose:
            self.terminal.write(message)
        self.log.write(self.re_color.sub('', message))
        self.log.flush()

    def flush(self):
        pass


class Color:
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    END = '\033[0m'


class Messages:
    def error(self, msg):
        print(Color.RED + msg + '. Check run_tests.log for more information' + Color.END)
        sys.exit(1)

    def info(self, msg):
        print(Color.YELLOW + msg + Color.END)

    def warning(self, msg):
        print(Color.YELLOW + msg + Color.END)

    def success(self, msg):
        print(Color.GREEN + msg + Color.END)

    def log(self, msg):
        print(msg)


class ArgParser:
    def __init__(self):
        self.parser = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter)

        self.parser.add_argument('-v', '--verbose', help='prints Vivado messages', action='store_true', default=False)

    def parse_args(self):
        args = self.parser.parse_args()
        return args

msg = Messages()
parser = ArgParser()
args = parser.parse_args()
sys.stdout = Logger()

if not spawn.find_executable('vivado'):
    msg.error('vivado not found. Please set PATH correctly')

prj_path = os.getcwd() + '/test_projects'
if not os.path.exists(prj_path):
    os.makedirs(prj_path)

for full_ip_name in ['extended/Lock']:
    msg.info('Running test for ' + full_ip_name + ' IP')
    ip_name = os.path.basename(full_ip_name)

    err = False    
    p = subprocess.Popen('vivado -nojournal -nolog -notrace -mode batch -source '
                         + os.getcwd() + '/scripts/run_test.tcl -tclargs '
                         + ip_name + ' ' 
                         + full_ip_name + ' '
                         + os.path.abspath(os.getcwd()),
                         cwd=prj_path,
                         stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, shell=True)

    for line in iter(p.stdout.readline, b''):
        line = line.decode('utf-8')
        if line.casefold().find('error') != -1:
            err = True
        sys.stdout.writeVerbose(line)

    retval = p.wait()
    if retval or err:
        msg.error('Test failed')
    else:
        msg.success('Test ok')


