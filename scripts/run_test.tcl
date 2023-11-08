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

variable name_IP [lindex $argv 0]
variable full_name_IP [lindex $argv 1]
#zcu102
variable board_part "xczu9eg-ffvc900-1-e"
variable root_dir [lindex $argv 2]
variable prj_dir "$root_dir/test_projects"


# Create project
create_project -force [string tolower $name_IP]_tb $prj_dir/[string tolower $name_IP]_tb -part $board_part
set_property simulator_language Verilog [current_project]

import_files -norecurse $root_dir/src/$full_name_IP.sv $root_dir/test/${full_name_IP}_tb.sv
import_files -norecurse $root_dir/src/pom_pkg.sv
import_files -norecurse $root_dir/picos/src/picos_pkg.sv

# Set top
set_property top ${name_IP}_tb [get_filesets sim_1]

# Run simulation enough time
launch_simulation
run 2000
