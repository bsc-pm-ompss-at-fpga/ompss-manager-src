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
import shutil
import subprocess
import argparse
from distutils import spawn
import xml.etree.cElementTree as cET


class Logger(object):
    def __init__(self):
        self.terminal = sys.stdout
        self.log = open('./ompss_manager.log', "w+")
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
        print(Color.RED + msg + '. Check ompss_manager.log for more information' + Color.END)
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
        self.parser = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter, prog='gen_ompss_ips')

        self.parser.add_argument('-b', '--board_part', help='board part number', metavar='BOARD', type=str.lower, required=True)
        self.parser.add_argument('-c', '--clock', help='FPGA clock frequency in MHz\n(def: \'100\')', type=int, default='100')
        self.parser.add_argument('--disable_tm', help='disables generation of Command TM IP', action='store_true', default=False)
        self.parser.add_argument('--disable_extended_tm', help='disables generation of Command ETM IP', action='store_true', default=False)
        self.parser.add_argument('-v', '--verbose', help='prints Vivado messages', action='store_true', default=False)
        self.parser.add_argument('-i', '--verbose_info', help='prints extra information messages', action='store_true', default=False)

    def parse_args(self):
        return self.parser.parse_args()


def generate_IP(extended=False):
    msg.info('Generating Command ' + ('E' if extended else '') + 'TM IP')

    if extended:
        prj_path = './ompss_manager_IP/Vivado/ext_tm/command_etm'
    else:
        prj_path = './ompss_manager_IP/Vivado/command_tm'

    p = subprocess.Popen('vivado -nojournal -nolog -notrace -mode batch -source '
                         + os.getcwd() + '/scripts/ompss_manager_ip_packager.tcl -tclargs '
                         + 'Command_' + ('E' if extended else '') + 'TM '
                         + '1.0 ' + args.board_part + ' ' + os.getcwd() + ' '
                         + os.path.abspath(os.getcwd() + '/ompss_manager_IP') + ' ' + str(extended), cwd=prj_path,
                         stdout=sys.stdout.subprocess,
                         stderr=sys.stdout.subprocess, shell=True)

    if args.verbose:
        for line in iter(p.stdout.readline, b''):
            sys.stdout.write(line.decode('utf-8'))

    retval = p.wait()
    if retval:
        msg.error('Generation of Command ' + ('E' if extended else '') + 'TM IP failed')
    else:
        msg.success('Finished generation of Command ' + ('E' if extended else '') + 'TM IP')


def synthesize_hls(file_, extended=False):
    acc_file = os.path.basename(file_)
    acc_name = os.path.splitext(acc_file)[0].replace('\.*', '')

    if extended:
        dst_path = './ompss_manager_IP/Vivado_HLS/ext_tm/'
    else:
        dst_path = './ompss_manager_IP/Vivado_HLS/'

    os.makedirs(dst_path + acc_name)
    shutil.copy2(file_, dst_path + acc_name + '/' + acc_file)

    ext_tm_cflags = ' -DEXT_OMPSS_MANAGER ' if extended else ''
    accel_tcl_script = '# Script automatically generated by autoVivado. Edit at your own risk.\n' \
                       + 'cd ../\n' \
                       + 'open_project ' + acc_name + '\n' \
                       + 'set_top ' + acc_name + '_wrapper\n' \
                       + 'add_files ' + acc_name + '/' + acc_file + ' -cflags "' + ext_tm_cflags + '"\n' \
                       + 'open_solution "solution1"\n' \
                       + 'set_part {' + args.board_part + '} -tool vivado\n' \
                       + 'create_clock -period ' + str(args.clock) + 'MHz -name default\n' \
                       + 'csynth_design\n' \
                       + 'export_design -rtl verilog -format ip_catalog -vendor bsc -library ompss -display_name ' + acc_name + ' -taxonomy /BSC/OmpSs\n' \
                       + 'exit\n'

    accel_tcl_script_file = open(dst_path + acc_name + '/HLS_' + acc_name + '.tcl', "w")
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

    #update_resource_utilization(file_)


msg = Messages()
parser = ArgParser()
args = parser.parse_args()
sys.stdout = Logger()

if spawn.find_executable('vivado_hls') and spawn.find_executable('vivado'):
    msg.info('Checking if your current version of Vivado supports the selected board part')
    os.system('echo "if {[llength [get_parts ' + args.board_part + ']] == 0} {exit 1}" > ./board_part_check.tcl')
    p = subprocess.Popen('vivado -nojournal -nolog -mode batch -source ./board_part_check.tcl', shell=True, stdout=open(os.devnull, 'w'))
    retval = p.wait()
    os.system('rm ./board_part_check.tcl')
    if (int(retval) == 1):
        msg.error("Your current version of Vivado does not support part " + args.board_part)

    msg.success('Success')

else:
    msg.error('vivado_hls or vivado not found. Please set PATH correctly')

if os.path.exists('./ompss_manager_IP'):
    shutil.rmtree('./ompss_manager_IP_old')
    os.rename('./ompss_manager_IP', './ompss_manager_IP_old')

# Synthesize HLS source codes
os.makedirs('./ompss_manager_IP/Vivado_HLS')

if not args.disable_tm:
    msg.info('Synthesizing Command TM HLS sources')
    for file_ in glob.glob('./src/*.cpp'):
        synthesize_hls(file_)

if not args.disable_extended_tm:
    msg.info('Synthesizing Command ETM HLS sources')
    for file_ in glob.glob('./src/*.cpp'):
        synthesize_hls(file_, True)

    for file_ in glob.glob('./src/ext_tm/*.cpp'):
        synthesize_hls(file_, True)

# Generate Vivado project and package IP
os.makedirs('./ompss_manager_IP/Vivado')
os.makedirs('./ompss_manager_IP/IP_packager')

if not args.disable_tm:
    os.makedirs('./ompss_manager_IP/Vivado/command_tm')
    generate_IP()

if not args.disable_extended_tm:
    os.makedirs('./ompss_manager_IP/Vivado/ext_tm/command_etm')
    generate_IP(True)

    #global available_resources
    #global used_resources

    #available_resources = dict()
    #used_resources = dict()

    #for acc in range(0, num_accels):
    #    file_ = accels[acc]

    #    synthesize_accelerator(file_)

    #if len(accels) > num_accels:
    #    msg.info('Synthesizing ' + str(len(accels) - num_accels) + ' additional support IP' + ('s' if len(accels) - num_accels > 1 else ''))

    #    for acc in range(num_accels, len(accels)):
    #        file_ = accels[acc]

    #        synthesize_accelerator(file_)

    #for resource in used_resources.items():
    #    available = available_resources[resource[0]]
    #    used = used_resources[resource[0]]
    #    if available > 0:
    #        utilization_percentage = str(round(float(used) / float(available) * 100, 2))
    #        report_string = '{0:<9} {1:>6} used | {2:>6} available - {3:>6}% utilization'
    #        report_string_formatted = report_string.format(resource[0], used, available, utilization_percentage)
    #        msg.info(report_string_formatted)


used_resources = {}

#for report in sys.argv[1:]:
#    tree = cET.parse(report)
#    root = tree.getroot()
#
#    for resource in root.find('AreaEstimates').find('Resources'):
#        used_resources[resource.tag] = int(resource.text) + (int(used_resources[resource.tag]) if resource.tag in used_resources else 0)
#
#
#print(used_resources)

#acc_file = os.path.basename(file_)
#acc_num_instances = int(acc_file.split(':')[1]) if len(acc_file.split(':')) > 1 else 1
#acc_file = acc_file.split(':')[2] if len(acc_file.split(':')) > 2 else acc_file
#acc_name = os.path.splitext(acc_file)[0].replace('_hls_automatic_mcxx', '')
#
#report_file = project_Vivado_HLS_path + '/' + acc_name + '/solution1/syn/report/' + acc_file.split('.')[0] + '_wrapper_csynth.xml'
#
#tree = cET.parse(report_file)
#root = tree.getroot()
#
#for resource in root.find('AreaEstimates').find('AvailableResources'):
#    available_resources[resource.tag] = int(resource.text)
#
#if args.verbose_info:
#    res_msg = 'Resources estimation for \'' + acc_name + '\''
#    first = True
#    for resource in root.find('AreaEstimates').find('Resources'):
#        res_msg += ': ' if first else ', '
#        res_msg += resource.text +  ' ' + resource.tag
#        first = False
#    msg.log(res_msg)
#
#for resource in root.find('AreaEstimates').find('Resources'):
#    used_resources[resource.tag] = int(resource.text) * acc_num_instances + (int(used_resources[resource.tag]) if resource.tag in used_resources else 0)
#    if used_resources[resource.tag] > available_resources[resource.tag] and not args.disable_utilization_check:
#        msg.error(resource.tag + ' utilization over 100% (' + str(used_resources[resource.tag]) + '/' + str(available_resources[resource.tag]) + ')')
#
#
