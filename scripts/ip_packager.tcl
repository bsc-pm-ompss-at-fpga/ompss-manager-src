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

variable name_IP [lindex $argv 0]
variable current_version [lindex $argv 1]
variable previous_version [lindex $argv 2]
variable root_dir [lindex $argv 3]
variable prj_dir [lindex $argv 4]
variable encrypt [lindex $argv 5]
variable advanced_hwruntime [lindex $argv 6]

variable vivado_version [regsub -all {\.} [version -short] {_}]

# Create project
create_project -force [string tolower $name_IP] $prj_dir/Vivado

import_files $root_dir/src
import_files $root_dir/picos/src

if {$encrypt == 1} {
    foreach hdl_file [get_files] {
        if {[file tail $hdl_file] != "${name_IP}_wrapper.v"} {
            encrypt -key $root_dir/vivado_keyfile_ver.txt -lang verilog $hdl_file
        }
    }
}

set_property top ${name_IP}_wrapper [current_fileset]

# Do not use . in the path because, at least in my computer, Vivado does not copy the sources when doing the package_project
set packager_dir $prj_dir/IP_packager/${name_IP}_[string map {. _} $current_version]_${vivado_version}_IP

ipx::package_project -root_dir $packager_dir -vendor bsc -library ompss -taxonomy /BSC/OmpSs -set_current true -force -force_update_compile_order -import_files

set_property name [string tolower $name_IP] [ipx::current_core]
set_property version $current_version [ipx::current_core]
set_property display_name "Picos OmpSs Manager" [ipx::current_core]
set_property description $name_IP [ipx::current_core]
set_property vendor_display_name {Barcelona Supercomputing Center (BSC-CNS)} [ipx::current_core]
set_property company_url https://pm.bsc.es/ompss-at-fpga [ipx::current_core]
set_property supported_families {zynquplus Beta zynq Beta virtex7 Beta kintexuplus Beta virtexuplus Beta virtexuplusHBM Beta kintexu Beta} [ipx::current_core]

ipx::add_file_group -type utility {} [ipx::current_core]

set hwruntime_short pom
file copy -force $root_dir/${hwruntime_short}_logo.png $packager_dir
ipx::add_file $packager_dir/${hwruntime_short}_logo.png [ipx::get_file_groups xilinx_utilityxitfiles -of_objects [ipx::current_core]]
set_property type LOGO [ipx::get_files ${hwruntime_short}_logo.png -of_objects [ipx::get_file_groups xilinx_utilityxitfiles -of_objects [ipx::current_core]]]

set_property widget {hexEdit} [ipgui::get_guiparamspec -name "SCHED_COUNT" -component [ipx::current_core] ]
set_property value 0x00000000000000000000000000000000 [ipx::get_user_parameters SCHED_COUNT -of_objects [ipx::current_core]]
set_property value 0x00000000000000000000000000000000 [ipx::get_hdl_parameters SCHED_COUNT -of_objects [ipx::current_core]]
set_property value_bit_string_length 128 [ipx::get_user_parameters SCHED_COUNT -of_objects [ipx::current_core]]
set_property value_bit_string_length 128 [ipx::get_hdl_parameters SCHED_COUNT -of_objects [ipx::current_core]]
set_property value_format bitString [ipx::get_user_parameters SCHED_COUNT -of_objects [ipx::current_core]]
set_property value_format bitString [ipx::get_hdl_parameters SCHED_COUNT -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {$ENABLE_TASK_CREATION} [ipx::get_user_parameters SCHED_COUNT -of_objects [ipx::current_core]]

set_property widget {hexEdit} [ipgui::get_guiparamspec -name "SCHED_ACCID" -component [ipx::current_core] ]
set_property value 0x00000000000000000000000000000000 [ipx::get_user_parameters SCHED_ACCID -of_objects [ipx::current_core]]
set_property value 0x00000000000000000000000000000000 [ipx::get_hdl_parameters SCHED_ACCID -of_objects [ipx::current_core]]
set_property value_bit_string_length 128 [ipx::get_user_parameters SCHED_ACCID -of_objects [ipx::current_core]]
set_property value_bit_string_length 128 [ipx::get_hdl_parameters SCHED_ACCID -of_objects [ipx::current_core]]
set_property value_format bitString [ipx::get_user_parameters SCHED_ACCID -of_objects [ipx::current_core]]
set_property value_format bitString [ipx::get_hdl_parameters SCHED_ACCID -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {$ENABLE_TASK_CREATION} [ipx::get_user_parameters SCHED_ACCID -of_objects [ipx::current_core]]

set_property widget {hexEdit} [ipgui::get_guiparamspec -name "SCHED_TTYPE" -component [ipx::current_core] ]
set_property value 0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 [ipx::get_user_parameters SCHED_TTYPE -of_objects [ipx::current_core]]
set_property value 0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 [ipx::get_hdl_parameters SCHED_TTYPE -of_objects [ipx::current_core]]
set_property value_bit_string_length 512 [ipx::get_user_parameters SCHED_TTYPE -of_objects [ipx::current_core]]
set_property value_bit_string_length 512 [ipx::get_hdl_parameters SCHED_TTYPE -of_objects [ipx::current_core]]
set_property value_format bitString [ipx::get_user_parameters SCHED_TTYPE -of_objects [ipx::current_core]]
set_property value_format bitString [ipx::get_hdl_parameters SCHED_TTYPE -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {$ENABLE_TASK_CREATION} [ipx::get_user_parameters SCHED_TTYPE -of_objects [ipx::current_core]]

set_property widget {checkBox} [ipgui::get_guiparamspec -name "AXILITE_INTF" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters AXILITE_INTF -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters AXILITE_INTF -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters AXILITE_INTF -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters AXILITE_INTF -of_objects [ipx::current_core]]

set_property widget {checkBox} [ipgui::get_guiparamspec -name "DBG_AVAIL_COUNT_EN" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters DBG_AVAIL_COUNT_EN -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters DBG_AVAIL_COUNT_EN -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters DBG_AVAIL_COUNT_EN -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters DBG_AVAIL_COUNT_EN -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {$AXILITE_INTF} [ipx::get_user_parameters DBG_AVAIL_COUNT_EN -of_objects [ipx::current_core]]

set_property widget {checkBox} [ipgui::get_guiparamspec -name "LOCK_SUPPORT" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters LOCK_SUPPORT -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters LOCK_SUPPORT -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters LOCK_SUPPORT -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters LOCK_SUPPORT -of_objects [ipx::current_core]]

set_property widget {checkBox} [ipgui::get_guiparamspec -name "ENABLE_SPAWN_QUEUES" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters ENABLE_SPAWN_QUEUES -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters ENABLE_SPAWN_QUEUES -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters ENABLE_SPAWN_QUEUES -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters ENABLE_SPAWN_QUEUES -of_objects [ipx::current_core]]

set_property widget {checkBox} [ipgui::get_guiparamspec -name "ENABLE_TASK_CREATION" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters ENABLE_TASK_CREATION -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters ENABLE_TASK_CREATION -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters ENABLE_TASK_CREATION -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters ENABLE_TASK_CREATION -of_objects [ipx::current_core]]

set_property value false [ipx::get_user_parameters ENABLE_DEPS -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters ENABLE_DEPS -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {$ENABLE_TASK_CREATION} [ipx::get_user_parameters ENABLE_DEPS -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters ENABLE_DEPS -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters ENABLE_DEPS -of_objects [ipx::current_core]]
ipx::update_dependency [ipx::get_user_parameters ENABLE_DEPS -of_objects [ipx::current_core]]

set_property widget {textEdit} [ipgui::get_guiparamspec -name "MAX_ACC_CREATORS" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters MAX_ACC_CREATORS -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 2 [ipx::get_user_parameters MAX_ACC_CREATORS -of_objects [ipx::current_core]]
# Arbitrary max range
set_property value_validation_range_maximum 8192 [ipx::get_user_parameters MAX_ACC_CREATORS -of_objects [ipx::current_core]]

set_property widget {textEdit} [ipgui::get_guiparamspec -name "DBG_AVAIL_COUNT_W" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters DBG_AVAIL_COUNT_W -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 1 [ipx::get_user_parameters DBG_AVAIL_COUNT_W -of_objects [ipx::current_core]]
set_property value_validation_range_maximum 64 [ipx::get_user_parameters DBG_AVAIL_COUNT_W -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {$AXILITE_INTF && $DBG_AVAIL_COUNT_EN} [ipx::get_user_parameters DBG_AVAIL_COUNT_W -of_objects [ipx::current_core]]

set_property widget {textEdit} [ipgui::get_guiparamspec -name "SPAWNIN_QUEUE_LEN" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters SPAWNIN_QUEUE_LEN -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 4 [ipx::get_user_parameters SPAWNIN_QUEUE_LEN -of_objects [ipx::current_core]]
# Arbitrary max range
set_property value_validation_range_maximum 8192 [ipx::get_user_parameters SPAWNIN_QUEUE_LEN -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {$ENABLE_SPAWN_QUEUES} [ipx::get_user_parameters SPAWNIN_QUEUE_LEN -of_objects [ipx::current_core]]

set_property widget {textEdit} [ipgui::get_guiparamspec -name "SPAWNOUT_QUEUE_LEN" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters SPAWNOUT_QUEUE_LEN -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 4 [ipx::get_user_parameters SPAWNOUT_QUEUE_LEN -of_objects [ipx::current_core]]
# Arbitrary max range
set_property value_validation_range_maximum 8192 [ipx::get_user_parameters SPAWNOUT_QUEUE_LEN -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {$ENABLE_SPAWN_QUEUES} [ipx::get_user_parameters SPAWNOUT_QUEUE_LEN -of_objects [ipx::current_core]]

set_property display_name {DM DS} [ipgui::get_guiparamspec -name "DM_DS" -component [ipx::current_core] ]
set_property tooltip {Data structure of the dependence memory} [ipgui::get_guiparamspec -name "DM_DS" -component [ipx::current_core] ]
set_property widget {comboBox} [ipgui::get_guiparamspec -name "DM_DS" -component [ipx::current_core] ]
set_property value_validation_type list [ipx::get_user_parameters DM_DS -of_objects [ipx::current_core]]
set_property value_validation_list {BINTREE LINKEDLIST} [ipx::get_user_parameters DM_DS -of_objects [ipx::current_core]]

set_property display_name {DM HASH} [ipgui::get_guiparamspec -name "DM_HASH" -component [ipx::current_core] ]
set_property tooltip {Dependence memory hash function} [ipgui::get_guiparamspec -name "DM_HASH" -component [ipx::current_core] ]
set_property widget {comboBox} [ipgui::get_guiparamspec -name "DM_HASH" -component [ipx::current_core] ]
set_property value_validation_type list [ipx::get_user_parameters DM_HASH -of_objects [ipx::current_core]]
set_property value_validation_list {P_PEARSON XOR} [ipx::get_user_parameters DM_HASH -of_objects [ipx::current_core]]

set_property widget {comboBox} [ipgui::get_guiparamspec -name "NUM_DCTS" -component [ipx::current_core] ]
set_property value_validation_type list [ipx::get_user_parameters NUM_DCTS -of_objects [ipx::current_core]]
set_property value_validation_list {1 2 4} [ipx::get_user_parameters NUM_DCTS -of_objects [ipx::current_core]]

set bram_list {spawnin_queue spawnout_queue}
foreach bram_intf $bram_list {
    ipx::remove_bus_interface ${bram_intf}_clk [ipx::current_core]
    ipx::remove_bus_interface ${bram_intf}_rst [ipx::current_core]
    ipx::infer_bus_interface "${bram_intf}_addr ${bram_intf}_clk ${bram_intf}_din ${bram_intf}_dout ${bram_intf}_en ${bram_intf}_rst ${bram_intf}_we" xilinx.com:interface:bram_rtl:1.0 [ipx::current_core]
    set_property interface_mode master [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]
    ipx::associate_bus_interfaces -busif $bram_intf -clock clk [ipx::current_core]
}

ipx::infer_bus_interface "axilite_arvalid axilite_arready axilite_araddr axilite_arprot axilite_rvalid axilite_rready axilite_rdata axilite_rresp" xilinx.com:interface:aximm_rtl:1.0 [ipx::current_core]
ipx::add_memory_map axilite [ipx::current_core]
set_property slave_memory_map_ref axilite [ipx::get_bus_interfaces axilite -of_objects [ipx::current_core]]
ipx::add_address_block reg_0 [ipx::get_memory_maps axilite -of_objects [ipx::current_core]]
set_property BASE_ADDRESS 0 [ipx::get_address_blocks reg_0 -of_objects [ipx::get_memory_maps axilite -of_objects [ipx::current_core]]]
set_property RANGE 16384 [ipx::get_address_blocks reg_0 -of_objects [ipx::get_memory_maps axilite -of_objects [ipx::current_core]]]
ipx::associate_bus_interfaces -busif axilite -clock clk [ipx::current_core]

ipx::associate_bus_interfaces -busif lock_in -clock clk [ipx::current_core]
ipx::associate_bus_interfaces -busif lock_out -clock clk [ipx::current_core]
ipx::associate_bus_interfaces -busif spawn_in -clock clk [ipx::current_core]
ipx::associate_bus_interfaces -busif spawn_out -clock clk [ipx::current_core]
ipx::associate_bus_interfaces -busif taskwait_in -clock clk [ipx::current_core]
ipx::associate_bus_interfaces -busif taskwait_out -clock clk [ipx::current_core]

set_property widget {textEdit} [ipgui::get_guiparamspec -name "MAX_ACCS" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters MAX_ACCS -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 2 [ipx::get_user_parameters MAX_ACCS -of_objects [ipx::current_core]]
# Arbitrary max range
set_property value_validation_range_maximum 8192 [ipx::get_user_parameters MAX_ACCS -of_objects [ipx::current_core]]

set_property widget {textEdit} [ipgui::get_guiparamspec -name "MAX_ACC_TYPES" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters MAX_ACC_TYPES -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 2 [ipx::get_user_parameters MAX_ACC_TYPES -of_objects [ipx::current_core]]
# Arbitrary max range
set_property value_validation_range_maximum 8192 [ipx::get_user_parameters MAX_ACC_TYPES -of_objects [ipx::current_core]]

set_property widget {textEdit} [ipgui::get_guiparamspec -name "CMDIN_SUBQUEUE_LEN" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters CMDIN_SUBQUEUE_LEN -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 4 [ipx::get_user_parameters CMDIN_SUBQUEUE_LEN -of_objects [ipx::current_core]]
# Arbitrary max range
set_property value_validation_range_maximum 8192 [ipx::get_user_parameters CMDIN_SUBQUEUE_LEN -of_objects [ipx::current_core]]

set_property widget {textEdit} [ipgui::get_guiparamspec -name "CMDOUT_SUBQUEUE_LEN" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters CMDOUT_SUBQUEUE_LEN -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 2 [ipx::get_user_parameters CMDOUT_SUBQUEUE_LEN -of_objects [ipx::current_core]]
# Arbitrary max range
set_property value_validation_range_maximum 8192 [ipx::get_user_parameters CMDOUT_SUBQUEUE_LEN -of_objects [ipx::current_core]]

ipx::add_bus_parameter POLARITY [ipx::get_bus_interfaces rstn -of_objects [ipx::current_core]]
set_property VALUE ACTIVE_LOW [ipx::get_bus_parameters POLARITY -of_objects [ipx::get_bus_interfaces rstn -of_objects [ipx::current_core]]]

ipx::associate_bus_interfaces -busif cmdin_out -clock clk [ipx::current_core]
ipx::associate_bus_interfaces -busif cmdout_in -clock clk [ipx::current_core]
ipx::associate_bus_interfaces -clock clk -reset rstn [ipx::current_core]

set bram_list {cmdin_queue cmdout_queue}
foreach bram_intf $bram_list {
    ipx::remove_bus_interface ${bram_intf}_clk [ipx::current_core]
    ipx::remove_bus_interface ${bram_intf}_rst [ipx::current_core]
    ipx::infer_bus_interface "${bram_intf}_addr ${bram_intf}_clk ${bram_intf}_din ${bram_intf}_dout ${bram_intf}_en ${bram_intf}_rst ${bram_intf}_we" xilinx.com:interface:bram_rtl:1.0 [ipx::current_core]
    set_property interface_mode master [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]
    ipx::associate_bus_interfaces -busif $bram_intf -clock clk [ipx::current_core]
}

set_property enablement_dependency {$AXILITE_INTF} [ipx::get_bus_interfaces axilite -of_objects [ipx::current_core]]
set_property enablement_dependency {$LOCK_SUPPORT} [ipx::get_bus_interfaces lock_in -of_objects [ipx::current_core]]
set_property enablement_dependency {$LOCK_SUPPORT} [ipx::get_bus_interfaces lock_out -of_objects [ipx::current_core]]
set_property enablement_dependency {$ENABLE_SPAWN_QUEUES} [ipx::get_bus_interfaces spawnin_queue -of_objects [ipx::current_core]]
set_property enablement_dependency {$ENABLE_SPAWN_QUEUES} [ipx::get_bus_interfaces spawnout_queue -of_objects [ipx::current_core]]
set_property enablement_dependency {$ENABLE_TASK_CREATION} [ipx::get_bus_interfaces spawn_in -of_objects [ipx::current_core]]
set_property enablement_dependency {$ENABLE_TASK_CREATION} [ipx::get_bus_interfaces spawn_out -of_objects [ipx::current_core]]
set_property enablement_dependency {$ENABLE_TASK_CREATION} [ipx::get_bus_interfaces taskwait_in -of_objects [ipx::current_core]]
set_property enablement_dependency {$ENABLE_TASK_CREATION} [ipx::get_bus_interfaces taskwait_out -of_objects [ipx::current_core]]

ipgui::add_page -name {Picos} -component [ipx::current_core] -display_name {Picos}
set_property display_name {POM} [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core] ]
set_property tooltip {} [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core] ]

set picos_params [list DM_DS DM_HASH DM_SIZE VM_SIZE HASH_T_SIZE NUM_DCTS TM_SIZE]

set i 0
foreach param $picos_params {
    set_property enablement_tcl_expr {$ENABLE_TASK_CREATION && $ENABLE_DEPS} [ipx::get_user_parameters $param -of_objects [ipx::current_core]]
    ipgui::move_param -component [ipx::current_core] -order $i [ipgui::get_guiparamspec -name $param -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Picos" -component [ipx::current_core]]
    incr i
}

set_property previous_version_for_upgrade bsc:ompss:[string tolower $name_IP]:$previous_version [ipx::current_core]
set_property core_revision 1 [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::check_integrity -quiet [ipx::current_core]
ipx::archive_core $prj_dir/IP_packager/bsc_ompss_[string tolower $name_IP]_${current_version}.zip [ipx::current_core]

