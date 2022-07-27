#!/usr/bin/env python3
#
#------------------------------------------------------------------------#
# Copyright (C) Barcelona Supercomputing Center                          #
#               Centro Nacional de Supercomputacion (BSC-CNS)            #
#                                                                        #
# All Rights Reserved.                                                   #
# This file is part of OmpSs@FPGA toolchain.                             #
#                                                                        #
# Unauthorized copying and/or distribution of this file,                 #
# via any medium is strictly prohibited.                                 #
# The intellectual and technical concepts contained herein are           #
# propietary to BSC-CNS and may be covered by Patents.                   #
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
        self.parser.add_argument('-w', '--no_warn', help='treat warnings as errors', action='store_true', default=False)
        self.parser.add_argument('--conf_seed', help='Configuration seed used to reproduce a test', type=int, default=0)
        self.parser.add_argument('--repeat_seed', help='Repetition seed used to reproduce a test', type=int, default=0)
        self.parser.add_argument('--task_creation', help='Use task creation for the test that is going to be reproduced', type=int)
        self.parser.add_argument('--hwruntime', help='Hwruntime for the test that is going to be reproduced', choices=['POM', 'SOM', 'FOM'])

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
            err = True                               # timescale warning code            module 'glbl' does not have a parameter named
        elif line_casefold.find('warning') != -1 and line.find('XSIM 43-4099') == -1 and line_casefold.find("module 'glbl'") == -1 and line.find("port 'clkB' is not connected on this instance") == -1:
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

if not spawn.find_executable('vivado'):
    msg.error('vivado not found. Please set PATH correctly')

prj_path = os.getcwd() + '/test_projects'
if not os.path.exists(prj_path):
    os.makedirs(prj_path)

if args.conf_seed != 0:
    exec_integration_test(1, 1, args.task_creation, 1000, args.conf_seed, args.repeat_seed, args.hwruntime)
else:
    # No task creation POM
    #exec_integration_test(10, 5, 0, 1000, 0, 0, 'POM')
    # Task creation with multiple levels of nesting POM
    exec_integration_test(10, 10, 1, 1000, 0, 0, 'POM')
    # Task creation with multiple levels of nesting SOM
    exec_integration_test(5, 5, 1, 1000, 0, 0, 'SOM')
    # No task creation FOM
    exec_integration_test(10, 5, 0, 1000, 0, 0, 'FOM')
