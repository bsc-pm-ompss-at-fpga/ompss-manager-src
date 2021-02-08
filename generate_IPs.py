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
import glob
import json
import shutil
import subprocess
import argparse
from distutils import spawn
import xml.etree.cElementTree as cET

SOM_MAJOR_VERSION = 3
SOM_MINOR_VERSION = 7

SOM_PREVIOUS_MAJOR_VERSION = 3
SOM_PREVIOUS_MINOR_VERSION = 6

POM_MAJOR_VERSION = 3
POM_MINOR_VERSION = 7

POM_PREVIOUS_MAJOR_VERSION = 3
POM_PREVIOUS_MINOR_VERSION = 6

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
        self.parser.add_argument('--skip_hls', help='skips the cleanup and HLS step', action='store_true', default=False)
        self.parser.add_argument('--skip_pom', help='skips the POM related parts', action='store_true', default=False)
        self.parser.add_argument('--skip_som', help='skips the SOM related parts', action='store_true', default=False)
        self.parser.add_argument('--skip_board_check', help='skips the board part check', action='store_true', default=False)
        self.parser.add_argument('--skip_pom_gen', help='skips generation of the POM IP', action='store_true', default=False)
        self.parser.add_argument('--skip_som_gen', help='skips generation of the SOM IP', action='store_true', default=False)
        self.parser.add_argument('--skip_pom_synth', help='skips POM IP synthesis to generate resouce utilization report', action='store_true', default=False)
        self.parser.add_argument('--skip_som_synth', help='skips SOM IP synthesis to generate resouce utilization report', action='store_true', default=False)
        self.parser.add_argument('--skip_int_IPs', help='skips generation of specified internal IPs (\'all\' disables all IPs)', nargs='+')
        self.parser.add_argument('--no_encrypt', help='do not encrypt IP source files', action='store_true', default=False)
        self.parser.add_argument('--max_accs', help='maximum number of accelerators supported by the IP (def: \'16\')', type=int, default=16)

    def parse_args(self):
        args = self.parser.parse_args()
        if args.skip_pom:
            args.skip_pom_gen = True
            args.skip_pom_synth = True
        if args.skip_som:
            args.skip_som_gen = True
            args.skip_som_synth = True
        return args

def parse_syntehsis_utilization_report(rpt_path, report_file, name_IP):
    if not os.path.exists(rpt_path):
        msg.warning('Cannot find rpt file ' + rpt_path + '. Skipping resource utilization report')
        return

    used_resources = {}
    with open(rpt_path, 'r') as rpt_file:
        rpt_data = rpt_file.readlines()

        # Search LUT/FF section
        # NOTE: Possible section names: Slice Logic, CLB Logic
        ids = [idx for idx in range(len(rpt_data) - 1) if ((re.match('^[0-9]\. Slice Logic\n', rpt_data[idx])
                                                            and rpt_data[idx + 1] == '--------------\n') or
                                                           (re.match('^[0-9]\. CLB Logic\n', rpt_data[idx])
                                                            and rpt_data[idx + 1] == '------------\n'))]
        if len(ids) != 1:
            msg.warning('Cannot find LUT/FF info in rpt file ' + rpt_path + '. Skipping bitstream utilization report')
            return

        # Get LUT
        elems = rpt_data[ids[0] + 6].split('|')
        used_resources['LUT'] = int(elems[2].strip())

        #skip 2 lines if there is LUT as memory
        elems = rpt_data[ids[0] + 8].split('|')
        memory_LUT = int(elems[2].strip())

        # Get FF
        elems = rpt_data[ids[0] + (11 if memory_LUT > 0 else 9)].split('|')
        used_resources['FF'] = int(elems[2].strip())

        # Get DSP
        # NOTE: Possible section names: DSP, ARITHMETIC
        ids = [idx for idx in range(len(rpt_data) - 1) if ((re.match('^[0-9]\. DSP\n', rpt_data[idx])
                                                            and rpt_data[idx + 1] == '------\n') or
                                                           (re.match('^[0-9]\. ARITHMETIC\n', rpt_data[idx])
                                                            and rpt_data[idx + 1] == '-------------\n'))]
        if len(ids) != 1:
            msg.warning('Cannot find DSP info in rpt file ' + rpt_path + '. Skipping bitstream utilization report')
            return
        elems = rpt_data[ids[0] + 6].split('|')
        used_resources['DSP48E'] = int(elems[2].strip())

        # Get BRAM
        # NOTE: Possible section names: Memory, BLOCKRAM
        ids = [idx for idx in range(len(rpt_data) - 1) if ((re.match('^[0-9]\. Memory\n', rpt_data[idx])
                                                           and rpt_data[idx + 1] == '---------\n') or
                                                          (re.match('^[0-9]\. BLOCKRAM\n', rpt_data[idx])
                                                           and rpt_data[idx + 1] == '-----------\n'))]
        if len(ids) != 1:
            msg.warning('Cannot find BRAM info in rpt file ' + rpt_path + '. Skipping bitstream utilization report')
            return
        elems = rpt_data[ids[0] + 6].split('|')
        used_resources['BRAM_18K'] = int(float(elems[2].strip())*2)

    msg.log(name_IP + ' resources utilization summary')
    for name in ['BRAM_18K', 'DSP48E', 'FF', 'LUT']:
        report_string = '{0:<9} {1:>6} used'
        report_string_formatted = report_string.format(name, used_resources[name])
        msg.log(report_string_formatted)

    with open(report_file, 'w') as json_file:
        json_file.write(json.dumps(used_resources))


def compute_POM_resource_utilization():
    msg.info('Synthesizing PicosOmpSsManager IP')
    prj_path = './pom_IP/Synthesis'
    p = subprocess.Popen('vivado -nojournal -nolog -notrace -mode batch -source '
                         + os.getcwd() + '/scripts/synthesize_pom.tcl -tclargs '
                         + os.path.abspath(os.getcwd() + '/pom_IP/Synthesis') + ' '
                         + 'PicosOmpSsManager '
                         + args.board_part + ' '
                         + os.path.abspath(os.getcwd() + '/pom_IP/IP_packager') + ' '
                         + str(args.max_accs), cwd=prj_path,
                         stdout=sys.stdout.subprocess,
                         stderr=sys.stdout.subprocess, shell=True)

    if args.verbose:
        for line in iter(p.stdout.readline, b''):
            sys.stdout.write(line.decode('utf-8'))

    retval = p.wait()
    if retval:
        msg.error('Synthesis of PicosOmpSsManager IP failed')
    else:
        msg.success('Finished synthesis of PicosOmpSsManager IP')

    parse_syntehsis_utilization_report(prj_path + '/synth_project.runs/synth_1/picosompssmanager_0_utilization_synth.rpt',
                                       './pom_IP/IP_packager/ext_pom_resource_utilization.json', 'PicosOmpSsManager')


def compute_SOM_resource_utilization(extended):
    msg.info('Synthesizing' + (' extended ' if extended else ' ') + 'SmartOmpSsManager IP')
    prj_path = './som_IP/Synthesis'
    p = subprocess.Popen('vivado -nojournal -nolog -notrace -mode batch -source '
                         + os.getcwd() + '/scripts/synthesize_som.tcl -tclargs '
                         + os.path.abspath(os.getcwd() + '/som_IP/Synthesis') + ' '
                         + 'SmartOmpSsManager '
                         + ('1 ' if extended else '0 ')
                         + args.board_part + ' '
                         + os.path.abspath(os.getcwd() + '/som_IP/IP_packager') + ' '
                         + str(args.max_accs), cwd=prj_path,
                         stdout=sys.stdout.subprocess,
                         stderr=sys.stdout.subprocess, shell=True)

    if args.verbose:
        for line in iter(p.stdout.readline, b''):
            sys.stdout.write(line.decode('utf-8'))

    retval = p.wait()
    if retval:
        msg.error('Synthesis of' + (' extended ' if extended else ' ') + 'SmartOmpSsManager IP failed')
    else:
        msg.success('Finished synthesis of' + (' extended ' if extended else ' ') + 'SmartOmpSsManager IP')

    parse_syntehsis_utilization_report(prj_path + '/synth_project.runs/synth_1/smartompssmanager_0_utilization_synth.rpt',
                                      './som_IP/IP_packager/' + ('ext_' if extended else '') + 'som_resource_utilization.json',
                                      ('Extended ' if extended else ' ') + 'SmartOmpSsManager')

def generate_internal_IP(ip_name):
    msg.info('Generating ' + ip_name + ' IP')

    if os.path.exists('./internal_IPs/' + ip_name + '_IP'):
        shutil.rmtree('./internal_IPs/' + ip_name + '_IP')

    os.makedirs('./internal_IPs/' + ip_name + '_IP/Vivado/' + ip_name)
    os.makedirs('./internal_IPs/' + ip_name + '_IP/IP_packager')

    prj_path = './internal_IPs/' + ip_name  + '_IP/Vivado/' + ip_name

    p = subprocess.Popen('vivado -nojournal -nolog -notrace -mode batch -source '
                         + os.getcwd() + '/scripts/' + ip_name + '_ip_packager.tcl -tclargs '
                         + ip_name + ' '
                         + args.board_part + ' ' + os.getcwd() + ' '
                         + os.path.abspath(os.getcwd() + '/internal_IPs/' + ip_name + '_IP') + ' '
                         + ('0' if args.no_encrypt else '1'), cwd=prj_path,
                         stdout=sys.stdout.subprocess,
                         stderr=sys.stdout.subprocess, shell=True)

    if args.verbose:
        for line in iter(p.stdout.readline, b''):
            sys.stdout.write(line.decode('utf-8'))

    retval = p.wait()
    if retval:
        msg.error('Generation of ' + ip_name +  ' IP failed')
    else:
        msg.success('Finished generation of ' + ip_name + ' IP')

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
                         + ('0' if args.no_encrypt else '1') + ' '
                         + str(args.max_accs), cwd=prj_path,
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
                         + os.path.abspath(os.getcwd() + '/som_IP') + ' '
                         + ('0' if args.no_encrypt else '1') + ' '
                         + str(args.max_accs), cwd=prj_path,
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
        msg.success('Finished synthesis of \'' + acc_name + '\'')


msg = Messages()
parser = ArgParser()
args = parser.parse_args()
sys.stdout = Logger()

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

    msg.info('Synthesizing HLS sources')
    for file_ in glob.glob('./src/*.cpp'):
        synthesize_hls(file_, ['./src/som.hpp'])

    for file_ in glob.glob('./src/extended/*.cpp'):
        synthesize_hls(file_, ['./src/som.hpp'], True)

internal_IPs = ['CutoffManager', 'Command_In_wrapper', 'Command_Out_wrapper', 'Scheduler_wrapper', 'Taskwait_wrapper', 'Lock_wrapper', 'Spawn_In_wrapper']

if args.skip_int_IPs is None or args.skip_int_IPs[0] != 'all':
    for ip_name in internal_IPs:
        if args.skip_int_IPs is None or ip_name not in args.skip_int_IPs:
            generate_internal_IP(ip_name)

if not args.skip_pom_gen:
    if os.path.exists('./pom_IP'):
        shutil.rmtree('./pom_IP_old', ignore_errors=True)
        os.rename('./pom_IP', './pom_IP_old')

    # Generate Vivado project and package IP
    os.makedirs('./pom_IP/Vivado/PicosOmpSsManager')
    os.makedirs('./pom_IP/IP_packager')

    generate_POM_IP()

if not args.skip_pom_synth:
    if os.path.exists('./pom_IP/Synthesis'):
        shutil.rmtree('./pom_IP/Synthesis')
    os.makedirs('./pom_IP/Synthesis')

    compute_POM_resource_utilization()

if not args.skip_som_gen:
    if os.path.exists('./som_IP'):
        shutil.rmtree('./som_IP_old', ignore_errors=True)
        os.rename('./som_IP', './som_IP_old')

    # Generate Vivado project and package IP
    os.makedirs('./som_IP/Vivado/SmartOmpSsManager')
    os.makedirs('./som_IP/IP_packager')

    generate_SOM_IP()

if not args.skip_som_synth:
    if os.path.exists('./som_IP/Synthesis'):
        shutil.rmtree('./som_IP/Synthesis')
    os.makedirs('./som_IP/Synthesis')

    compute_SOM_resource_utilization(False)
    compute_SOM_resource_utilization(True)
