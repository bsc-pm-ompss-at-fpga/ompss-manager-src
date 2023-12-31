#!/usr/bin/env python3

# ------------------------------------------------------------------------- #
#   Copyright (C) 2020-2023 Barcelona Supercomputing Center                 #
#                   Centro Nacional de Supercomputacion (BSC-CNS)           #
#                                                                           #
#   This file is part of OmpSs@FPGA toolchain.                              #
#                                                                           #
#   This program is free software: you can redistribute it and/or modify    #
#   it under the terms of the GNU General Public License as published       #
#   by the Free Software Foundation, either version 3 of the License,       #
#   or (at your option) any later version.                                  #
#                                                                           #
#   This program is distributed in the hope that it will be useful,         #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of          #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                    #
#   See the GNU General Public License for more details.                    #
#                                                                           #
#   You should have received a copy of the GNU General Public License       #
#   along with this program. If not, see <https://www.gnu.org/licenses/>.   #
# ------------------------------------------------------------------------- #

import argparse
import os
import re
import shutil
import sys
import subprocess


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
        self.parser.add_argument('-w', '--no_warn', help='treat warnings as errors', action='store_true', default=False)
        self.parser.add_argument('ip', nargs='*', help='IP which testbench will be run (if none, all IPs are assumed)', default=['advanced/Lock', 'advanced/Scheduler', 'advanced/Scheduler_spawnout'])

    def parse_args(self):
        args = self.parser.parse_args()
        return args


def exec_integration_test(num_confs, repeats, task_creation, max_commands, reproduce_conf_seed, reproduce_repeat_seed, hwruntime):
    err = False
    warn = False
    msg.info('Running integration test with {} configurations, {} repetitions, {}, {} max commands, {}'.format(num_confs, repeats, 'task creation' if task_creation else 'no task creation', max_commands, hwruntime))
    p = subprocess.Popen('vivado -nojournal -nolog -notrace -mode batch -source '
                         + os.getcwd() + '/scripts/run_integration_test.tcl -tclargs '
                         + os.path.abspath(os.getcwd()) + ' '
                         + str(num_confs) + ' '
                         + str(repeats) + ' '
                         + str(task_creation) + ' '
                         + str(max_commands) + ' '
                         + str(reproduce_conf_seed) + ' '
                         + str(reproduce_repeat_seed) + ' '
                         + hwruntime,
                         cwd=prj_path,
                         stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, shell=True)

    for line in iter(p.stdout.readline, b''):
        line = line.decode('utf-8')
        line_casefold = line.casefold()
        if line_casefold.find('error') != -1:
            err = True                                       # timescale warning code                        module 'glbl' does not have a parameter named
        elif line_casefold.find('warning') != -1 and line.find('XSIM 43-4099') == -1 and line_casefold.find("module 'glbl'") == -1:
            warn = True
        sys.stdout.writeVerbose(line)

    retval = p.wait()
    if retval or err:
        msg.error('Test failed')
    elif args.no_warn and warn:
        msg.error('Test failed due to warning')
    elif warn:
        msg.success('Test ok (but there are some warnings)')
    else:
        msg.success('Test ok')


msg = Messages()
parser = ArgParser()
args = parser.parse_args()
sys.stdout = Logger()

if not shutil.which('vivado'):
    msg.error('vivado not found. Please set PATH correctly')

prj_path = os.getcwd() + '/test_projects'
if not os.path.exists(prj_path):
    os.makedirs(prj_path)

for full_ip_name in args.ip:
    msg.info('Running test for ' + full_ip_name + ' IP')
    ip_name = os.path.basename(full_ip_name)

    err = False
    warn = False
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
        line_casefold = line.casefold()
        if line_casefold.find('error') != -1:
            err = True
        elif line_casefold.find('warning') != -1 and line_casefold.find('has a timescale but') == -1:
            warn = True
        sys.stdout.writeVerbose(line)

    retval = p.wait()
    if retval or err:
        msg.error('Test failed')
    elif args.no_warn and warn:
        msg.error('Test failed due to warning')
    elif warn:
        msg.success('Test ok (but there are some warnings)')
    else:
        msg.success('Test ok')
