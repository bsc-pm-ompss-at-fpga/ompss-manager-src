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
import_files -norecurse $root_dir/src/OmpSsManagerConfig.sv

# Set top
set_property top ${name_IP}_tb [get_filesets sim_1]

# Run simulation enough time
launch_simulation
run 1000
