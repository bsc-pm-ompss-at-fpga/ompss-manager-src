#!/usr/bin/env python
#
#------------------------------------------------------------------------#
#    (C) Copyright 2017-2019 Barcelona Supercomputing Center             #
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
import glob
import json
import shutil
import subprocess
import argparse
from distutils import spawn
import xml.etree.cElementTree as cET

SOM_MAJOR_VERSION = 2
SOM_MINOR_VERSION = 0

SOM_PREVIOUS_MAJOR_VERSION = 1
SOM_PREVIOUS_MINOR_VERSION = 6

POM_MAJOR_VERSION = 1
POM_MINOR_VERSION = 0

POM_PREVIOUS_MAJOR_VERSION = 0
POM_PREVIOUS_MINOR_VERSION = 0

class Logger(object):
    def __init__(self):
        self.terminal = sys.stdout
        self.log = open('generate_IPs.log', 'w+')
        self.subprocess = subprocess.PIPE if args.verbose else self.log
        self.re_color = re.compile(r'\033\[[0,1][0-9,;]*m')

    def write(self, message):
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
        print(Color.RED + msg + '. Check generate_IPs.log for more information' + Color.END)
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

        self.parser.add_argument('-b', '--board_part', help='board part number', metavar='BOARD_PART', type=str.lower, required=True)
        self.parser.add_argument('-c', '--clock', help='FPGA clock frequency in MHz\n(def: \'100\')', type=int, default='100')
        self.parser.add_argument('-v', '--verbose', help='prints Vivado messages', action='store_true', default=False)
        self.parser.add_argument('-p', '--picos_path', help='Path to the Picos IP', required=True)
        self.parser.add_argument('--skip_hls', help='skips the cleanup and HLS step', action='store_true', default=False)
        self.parser.add_argument('--skip_board_check', help='skips the board part check', action='store_true', default=False)
        self.parser.add_argument('--skip_cutoff_gen', help='skips generation of the CutoffManager IP', action='store_true', default=False)
        self.parser.add_argument('--skip_pom_gen', help='skips generation of the PicosOmpSsManager IP', action='store_true', default=False)
        self.parser.add_argument('--skip_som_gen', help='skips generation of the SmartOmpSsManager IP', action='store_true', default=False)

    def parse_args(self):
        return self.parser.parse_args()


def compute_resource_utilization(acc_path, extended=False):
    report_file = acc_path + '/solution1/syn/report/' + os.path.basename(acc_path) + '_wrapper_csynth.xml'

    tree = cET.parse(report_file)
    root = tree.getroot()

    for resource in root.find('AreaEstimates').find('Resources'):
        if not extended:
            used_resources[False][resource.tag] = int(resource.text) + (int(used_resources[extended][resource.tag]) if resource.tag in used_resources[extended] else 0)

        used_resources[True][resource.tag] = int(resource.text) + (int(used_resources[extended][resource.tag]) if resource.tag in used_resources[extended] else 0)

def generate_cutoff_IP():
    msg.info('Generating CutoffManager IP')

    prj_path = './cutoff_IP/Vivado/CutoffManager'

    p = subprocess.Popen('vivado -nojournal -nolog -notrace -mode batch -source '
                         + os.getcwd() + '/scripts/cutoff_ip_packager.tcl -tclargs '
                         + 'CutoffManager '
                         + args.board_part + ' ' + os.getcwd() + ' '
                         + os.path.abspath(os.getcwd() + '/cutoff_IP'), cwd=prj_path,
                         stdout=sys.stdout.subprocess,
                         stderr=sys.stdout.subprocess, shell=True)

    if args.verbose:
        for line in iter(p.stdout.readline, b''):
            sys.stdout.write(line.decode('utf-8'))

    retval = p.wait()
    if retval:
        msg.error('Generation of CutoffManager IP failed')
    else:
        msg.success('Finished generation of CutoffManager IP')

def generate_POM_IP():
    msg.info('Generating PicosOmpSsManager IP')

    prj_path = './pom_IP/Vivado/PicosOmpSsManager'

    p = subprocess.Popen('vivado -nojournal -nolog -notrace -mode batch -source '
                         + os.getcwd() + '/scripts/pom_ip_packager.tcl -tclargs '
                         + 'PicosOmpSsManager '
                         + str(POM_MAJOR_VERSION) + '.' + str(POM_MINOR_VERSION) + ' '
                         + str(POM_PREVIOUS_MAJOR_VERSION) + '.' + str(POM_PREVIOUS_MINOR_VERSION) + ' '
                         + args.board_part + ' ' + os.getcwd() + ' '
                         + os.path.abspath(os.getcwd() + '/pom_IP') + ' '
                         + args.picos_path, cwd=prj_path,
                         stdout=sys.stdout.subprocess,
                         stderr=sys.stdout.subprocess, shell=True)

    if args.verbose:
        for line in iter(p.stdout.readline, b''):
            sys.stdout.write(line.decode('utf-8'))

    retval = p.wait()
    if retval:
        msg.error('Generation of PicosOmpSsManager IP failed')
    else:
        msg.success('Finished generation of PicosOmpSsManager IP')

def generate_SOM_IP():
    msg.info('Generating SmartOmpSsManager IP')

    prj_path = './som_IP/Vivado/SmartOmpSsManager'

    p = subprocess.Popen('vivado -nojournal -nolog -notrace -mode batch -source '
                         + os.getcwd() + '/scripts/som_ip_packager.tcl -tclargs '
                         + 'SmartOmpSsManager '
                         + str(SOM_MAJOR_VERSION) + '.' + str(SOM_MINOR_VERSION) + ' '
                         + str(SOM_PREVIOUS_MAJOR_VERSION) + '.' + str(SOM_PREVIOUS_MINOR_VERSION) + ' '
                         + args.board_part + ' ' + os.getcwd() + ' '
                         + os.path.abspath(os.getcwd() + '/som_IP'), cwd=prj_path,
                         stdout=sys.stdout.subprocess,
                         stderr=sys.stdout.subprocess, shell=True)

    if args.verbose:
        for line in iter(p.stdout.readline, b''):
            sys.stdout.write(line.decode('utf-8'))

    retval = p.wait()
    if retval:
        msg.error('Generation of SmartOmpSsManager IP failed')
    else:
        msg.success('Finished generation of SmartOmpSsManager IP')

def synthesize_hls(file_, includes, extended=False):
    acc_file = os.path.basename(file_)
    acc_name = os.path.splitext(acc_file)[0].replace('\.*', '')

    if extended:
        dst_path = './Vivado_HLS/extended/'
    else:
        dst_path = './Vivado_HLS/'

    os.makedirs(dst_path + acc_name)
    shutil.copy2(file_, dst_path + acc_name + '/' + acc_file)
    for include in includes:
        include_file = os.path.basename(include)
        shutil.copy2(include, dst_path + acc_name + '/' + include_file)

    accel_tcl_script = '# Script automatically generated by the Accelerator Integration Tool. Edit at your own risk.\n' \
                       + 'cd ../\n' \
                       + 'open_project ' + acc_name + '\n' \
                       + 'set_top ' + acc_name + '_wrapper\n' \
                       + 'add_files ' + acc_name + '/' + acc_file + '\n' \
                       + 'open_solution "solution1"\n' \
                       + 'set_part {' + args.board_part + '} -tool vivado\n' \
                       + 'create_clock -period ' + str(args.clock) + 'MHz -name default\n' \
                       + 'csynth_design\n' \
                       + 'export_design -rtl verilog -format ip_catalog -vendor bsc -library ompss -display_name ' + acc_name + ' -taxonomy /BSC/OmpSs\n' \
                       + 'exit\n'

    accel_tcl_script_file = open(dst_path + acc_name + '/HLS_' + acc_name + '.tcl', 'w')
    accel_tcl_script_file.write(accel_tcl_script)
    accel_tcl_script_file.close()

    msg.info('Synthesizing \'' + acc_name + '\'')
    p = subprocess.Popen('vivado_hls ' + 'HLS_' + acc_name + '.tcl -l '
                         + 'HLS_' + acc_name + '.log', cwd=dst_path + acc_name,
                         stdout=sys.stdout.subprocess, stderr=sys.stdout.subprocess, shell=True)
    if args.verbose:
        for line in iter(p.stdout.readline, b''):
            sys.stdout.write(line.decode('utf-8'))

    retval = p.wait()
    if retval:
        msg.error('Synthesis of \'' + acc_name + '\' failed')
    else:
        compute_resource_utilization(dst_path + acc_name, extended)
        msg.success('Finished synthesis of \'' + acc_name + '\'')


msg = Messages()
parser = ArgParser()
args = parser.parse_args()
sys.stdout = Logger()

if not args.skip_pom_gen and args.picos_path is None:
    msg.error('Please specify the Picos IP path with the -p option')

if spawn.find_executable('vivado_hls') and spawn.find_executable('vivado'):
    if not args.skip_board_check:
        msg.info('Checking if your current version of Vivado supports the selected board part')
        os.system('echo "if {[llength [get_parts ' + args.board_part + ']] == 0} {exit 1}" > ./board_part_check.tcl')
        p = subprocess.Popen('vivado -nojournal -nolog -mode batch -source ./board_part_check.tcl', shell=True, stdout=open(os.devnull, 'w'))
        retval = p.wait()
        os.system('rm ./board_part_check.tcl')
        if (int(retval) == 1):
            msg.error('Your current version of Vivado does not support part ' + args.board_part)

        msg.success('Success')

else:
    msg.error('vivado_hls or vivado not found. Please set PATH correctly')

if not args.skip_hls:

    # Synthesize HLS source codes
    shutil.rmtree('./Vivado_HLS', ignore_errors=True)
    os.makedirs('./Vivado_HLS')
    used_resources = {True:{},False:{}}

    msg.info('Synthesizing PicosOmpSsManager HLS sources')
    for file_ in glob.glob('./src/*.cpp'):
        synthesize_hls(file_, ['./src/som.hpp'])

    for file_ in glob.glob('./src/extended/*.cpp'):
        synthesize_hls(file_, ['./src/som.hpp'], True)

if not args.skip_cutoff_gen:
    if os.path.exists('./cutoff_IP'):
        shutil.rmtree('./cutoff_IP_old', ignore_errors=True)
        os.rename('./cutoff_IP', './cutoff_IP_old')

    os.makedirs('./cutoff_IP/Vivado/CutoffManager')
    os.makedirs('./cutoff_IP/IP_packager')

    generate_cutoff_IP()

if not args.skip_pom_gen:
    if os.path.exists('./pom_IP'):
        shutil.rmtree('./pom_IP_old', ignore_errors=True)
        os.rename('./pom_IP', './pom_IP_old')

    # Generate Vivado project and package IP
    os.makedirs('./pom_IP/Vivado/PicosOmpSsManager')
    os.makedirs('./pom_IP/IP_packager')

    generate_POM_IP()

if not args.skip_som_gen:
    if os.path.exists('./som_IP'):
        shutil.rmtree('./som_IP_old', ignore_errors=True)
        os.rename('./som_IP', './som_IP_old')

    # Generate Vivado project and package IP
    os.makedirs('./som_IP/Vivado/SmartOmpSsManager')
    os.makedirs('./som_IP/IP_packager')

    if not args.skip_hls:
        # SmartOmpSsManager utilization
        f = open('./som_IP/IP_packager/som_resource_utilization.json', 'w')
        f.write(json.dumps(used_resources[False]) + '\n')
        f.close()

        # Extended SmartOmpSsManager utilization
        f = open('./som_IP/IP_packager/ext_som_resource_utilization.json', 'w')
        f.write(json.dumps(used_resources[True]) + '\n')
        f.close()

    generate_SOM_IP()

