#-------------------------------------------------------------------------#
#  Copyright (C) 2020-2023 Barcelona Supercomputing Center                #
#                  Centro Nacional de Supercomputacion (BSC-CNS)          #
#                                                                         #
#  This file is part of OmpSs@FPGA toolchain.                             #
#                                                                         #
#  This program is free software: you can redistribute it and/or modify   #
#  it under the terms of the GNU General Public License as published      #
#  by the Free Software Foundation, either version 3 of the License,      #
#  or (at your option) any later version.                                 #
#                                                                         #
#  This program is distributed in the hope that it will be useful,        #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of         #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                   #
#  See the GNU General Public License for more details.                   #
#                                                                         #
#  You should have received a copy of the GNU General Public License      #
#  along with this program. If not, see <https://www.gnu.org/licenses/>.  #
#-------------------------------------------------------------------------#

variable project_path [lindex $argv 0]
variable name_IP [lindex $argv 1]
variable part [lindex $argv 2]
variable ip_repo_path [lindex $argv 3]

set name_IP_lower [ string tolower $name_IP ]
set mod_name ${name_IP_lower}_0

if { [ glob -nocomplain $project_path/synth_project.xpr ] == "" } {
    create_project synth_project $project_path -part $part

    set_property ip_repo_paths $ip_repo_path [current_project]
    update_ip_catalog

    set ip [create_ip -name $name_IP_lower -vendor bsc -library ompss -module_name $mod_name]

    set_property generate_synth_checkpoint false $ip
} else {
    open_project $project_path/synth_project.xpr
}

# Enable all feature to have a better resource utilization statistic
set_property -dict [list \
   CONFIG.ENABLE_TASK_CREATION 1 \
   CONFIG.LOCK_SUPPORT 1 \
   CONFIG.ENABLE_SPAWN_QUEUES 1 \
   CONFIG.AXILITE_INTF 1 \
   CONFIG.DBG_AVAIL_COUNT_EN 1 \
   CONFIG.DBG_AVAIL_COUNT_W 64 \
] [get_ips $mod_name]

reset_run synth_1

launch_runs synth_1

wait_on_run synth_1

# Check if synthesis finished correctly
if {[string match "*ERROR*" [get_property STATUS [get_runs synth_1]]]} {
	error "ERROR: Hardware synthesis failed."
}

