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

variable vivado_version [regsub -all {\.} [version -short] {_}]

# Create project
create_project -force [string tolower $name_IP]

import_files $root_dir/src

if {$name_IP == "PicosOmpSsManager"} {
   import_files $root_dir/picos/src
}

if {$encrypt == 1} {
    foreach hdl_file [get_files] {
        if {[file tail $hdl_file] != "${name_IP}_wrapper.v" && [file tail $hdl_file] != "config.sv"} {
            encrypt -key $root_dir/vivado_keyfile_ver.txt -lang verilog $hdl_file
        }
    }
}

# NOTE: No zip IPs are used now, but they may be used again in the future
#set_property ip_repo_paths "$root_dir/IPs" [current_project]
#update_ip_catalog
#
#foreach {IP} [glob -nocomplain $root_dir/IPs/*.zip] {
#    if { ![ file exists [ file rootname $IP ] ] } {
#        update_ip_catalog -add_ip $IP -repo_path $root_dir/IPs
#    }
#    import_files [file rootname $IP]/src
#}

set_property top ${name_IP}_wrapper [current_fileset]
update_compile_order -fileset sources_1

ipx::package_project -root_dir $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP -vendor bsc -library ompss -taxonomy /BSC/OmpSs -generated_files -import_files -set_current false
ipx::unload_core $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/component.xml

set_property name [string tolower $name_IP] [ipx::current_core]
set_property version $current_version [ipx::current_core]
set_property display_name $name_IP [ipx::current_core]
set_property description $name_IP [ipx::current_core]
set_property vendor_display_name {Barcelona Supercomputing Center (BSC-CNS)} [ipx::current_core]
set_property company_url https://pm.bsc.es/ompss-at-fpga [ipx::current_core]
set_property supported_families {zynquplus Beta zynq Beta virtex7 Beta kintexu Beta virtexuplus Beta virtexuplusHBM Beta} [ipx::current_core]

ipx::add_file_group -type utility {} [ipx::current_core]
if {$name_IP == "SmartOmpSsManager"} {
    set hwruntime_short som
} else {
    set hwruntime_short pom
    ipx::add_user_parameter PICOS_ARGS [ipx::current_core]
    set_property value_resolve_type user [ipx::get_user_parameters PICOS_ARGS -of_objects [ipx::current_core]]
    ipgui::add_param -name {PICOS_ARGS} -component [ipx::current_core]
    set_property display_name {Picos Args} [ipgui::get_guiparamspec -name "PICOS_ARGS" -component [ipx::current_core] ]
    set_property widget {textEdit} [ipgui::get_guiparamspec -name "PICOS_ARGS" -component [ipx::current_core] ]
    ipgui::move_param -component [ipx::current_core] -order 8 [ipgui::get_guiparamspec -name "PICOS_ARGS" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
}
file copy -force $root_dir/${hwruntime_short}_logo.png $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/src/
ipx::add_file $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/src/${hwruntime_short}_logo.png [ipx::get_file_groups xilinx_utilityxitfiles -of_objects [ipx::current_core]]
set_property type LOGO [ipx::get_files src/${hwruntime_short}_logo.png -of_objects [ipx::get_file_groups xilinx_utilityxitfiles -of_objects [ipx::current_core]]]

update_compile_order -fileset sources_1
ipx::merge_project_changes hdl_parameters [ipx::current_core]

set_property widget {checkBox} [ipgui::get_guiparamspec -name "EXTENDED_MODE" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters EXTENDED_MODE -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters EXTENDED_MODE -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters EXTENDED_MODE -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters EXTENDED_MODE -of_objects [ipx::current_core]]

set_property widget {checkBox} [ipgui::get_guiparamspec -name "LOCK_SUPPORT" -component [ipx::current_core] ]
set_property value false [ipx::get_user_parameters LOCK_SUPPORT -of_objects [ipx::current_core]]
set_property value false [ipx::get_hdl_parameters LOCK_SUPPORT -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_user_parameters LOCK_SUPPORT -of_objects [ipx::current_core]]
set_property value_format bool [ipx::get_hdl_parameters LOCK_SUPPORT -of_objects [ipx::current_core]]

set_property widget {textEdit} [ipgui::get_guiparamspec -name "MAX_ACCS" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters MAX_ACCS -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 2 [ipx::get_user_parameters MAX_ACCS -of_objects [ipx::current_core]]
# Arbitrary max range
set_property value_validation_range_maximum 8192 [ipx::get_user_parameters MAX_ACCS -of_objects [ipx::current_core]]

set_property widget {textEdit} [ipgui::get_guiparamspec -name "MAX_ACC_CREATORS" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters MAX_ACC_CREATORS -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 2 [ipx::get_user_parameters MAX_ACC_CREATORS -of_objects [ipx::current_core]]
# Arbitrary max range
set_property value_validation_range_maximum 8192 [ipx::get_user_parameters MAX_ACC_CREATORS -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {expr $EXTENDED_MODE == true} [ipx::get_user_parameters MAX_ACC_CREATORS -of_objects [ipx::current_core]]

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

set_property widget {textEdit} [ipgui::get_guiparamspec -name "SPAWNIN_QUEUE_LEN" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters SPAWNIN_QUEUE_LEN -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 4 [ipx::get_user_parameters SPAWNIN_QUEUE_LEN -of_objects [ipx::current_core]]
# Arbitrary max range
set_property value_validation_range_maximum 8192 [ipx::get_user_parameters SPAWNIN_QUEUE_LEN -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {expr $EXTENDED_MODE == true} [ipx::get_user_parameters SPAWNIN_QUEUE_LEN -of_objects [ipx::current_core]]

set_property widget {textEdit} [ipgui::get_guiparamspec -name "SPAWNOUT_QUEUE_LEN" -component [ipx::current_core] ]
set_property value_validation_type range_long [ipx::get_user_parameters SPAWNOUT_QUEUE_LEN -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 4 [ipx::get_user_parameters SPAWNOUT_QUEUE_LEN -of_objects [ipx::current_core]]
# Arbitrary max range
set_property value_validation_range_maximum 8192 [ipx::get_user_parameters SPAWNOUT_QUEUE_LEN -of_objects [ipx::current_core]]
set_property enablement_tcl_expr {expr $EXTENDED_MODE == true} [ipx::get_user_parameters SPAWNOUT_QUEUE_LEN -of_objects [ipx::current_core]]

ipx::associate_bus_interfaces -busif cmdin_out -clock aclk [ipx::current_core]
ipx::associate_bus_interfaces -busif cmdout_in -clock aclk [ipx::current_core]
ipx::associate_bus_interfaces -busif lock_in -clock aclk [ipx::current_core]
ipx::associate_bus_interfaces -busif lock_out -clock aclk [ipx::current_core]
ipx::associate_bus_interfaces -busif spawn_in -clock aclk [ipx::current_core]
ipx::associate_bus_interfaces -busif spawn_out -clock aclk [ipx::current_core]
ipx::associate_bus_interfaces -busif taskwait_in -clock aclk [ipx::current_core]
ipx::associate_bus_interfaces -busif taskwait_out -clock aclk [ipx::current_core]
ipx::associate_bus_interfaces -clock aclk -reset managed_aresetn [ipx::current_core]
ipx::associate_bus_interfaces -clock aclk -reset interconnect_aresetn [ipx::current_core]
ipx::associate_bus_interfaces -clock aclk -reset peripheral_aresetn [ipx::current_core]
ipx::associate_bus_interfaces -clock aclk -reset ps_rst [ipx::current_core]
ipx::add_bus_parameter POLARITY [ipx::get_bus_interfaces ps_rst -of_objects [ipx::current_core]]

set bram_list {cmdin_queue cmdout_queue bitinfo spawnin_queue spawnout_queue}

foreach bram_intf $bram_list {
    ipx::remove_bus_interface ${bram_intf}_clk [ipx::current_core]
    ipx::remove_bus_interface ${bram_intf}_rst [ipx::current_core]
    if {$bram_intf == "bitinfo"} {
        ipx::infer_bus_interface "${bram_intf}_addr ${bram_intf}_clk ${bram_intf}_dout ${bram_intf}_en ${bram_intf}_rst" xilinx.com:interface:bram_rtl:1.0 [ipx::current_core]
    } else {
        ipx::infer_bus_interface "${bram_intf}_addr ${bram_intf}_clk ${bram_intf}_din ${bram_intf}_dout ${bram_intf}_en ${bram_intf}_rst ${bram_intf}_we" xilinx.com:interface:bram_rtl:1.0 [ipx::current_core]
    }
    set_property interface_mode master [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]
    ipx::associate_bus_interfaces -busif $bram_intf -clock aclk [ipx::current_core]
}

set_property enablement_dependency {$LOCK_SUPPORT = 1} [ipx::get_bus_interfaces lock_in -of_objects [ipx::current_core]]
set_property enablement_dependency {$LOCK_SUPPORT = 1} [ipx::get_bus_interfaces lock_out -of_objects [ipx::current_core]]
set_property enablement_dependency {$EXTENDED_MODE = 1} [ipx::get_bus_interfaces spawn_in -of_objects [ipx::current_core]]
set_property enablement_dependency {$EXTENDED_MODE = 1} [ipx::get_bus_interfaces spawn_out -of_objects [ipx::current_core]]
set_property enablement_dependency {$EXTENDED_MODE = 1} [ipx::get_bus_interfaces taskwait_in -of_objects [ipx::current_core]]
set_property enablement_dependency {$EXTENDED_MODE = 1} [ipx::get_bus_interfaces taskwait_out -of_objects [ipx::current_core]]
set_property enablement_dependency {$EXTENDED_MODE = 1} [ipx::get_bus_interfaces bitinfo -of_objects [ipx::current_core]]
set_property enablement_dependency {$EXTENDED_MODE = 1} [ipx::get_bus_interfaces spawnin_queue -of_objects [ipx::current_core]]
set_property enablement_dependency {$EXTENDED_MODE = 1} [ipx::get_bus_interfaces spawnout_queue -of_objects [ipx::current_core]]

set_property previous_version_for_upgrade bsc:ompss:[string tolower $name_IP]:$previous_version [ipx::current_core]
set_property core_revision 1 [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::check_integrity -quiet [ipx::current_core]
ipx::archive_core $prj_dir/IP_packager/bsc_ompss_[string tolower $name_IP]_${current_version}.zip [ipx::current_core]

set component_path $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/component.xml
exec sed -i "s/<spirit:value spirit:id=\\\"BUSIFPARAM_VALUE.PS_RST.POLARITY\\\"\\\/>/<spirit:value spirit:id=\\\"BUSIFPARAM_VALUE.PS_RST.POLARITY\\\">ACTIVE_HIGH<\\\/spirit:value>/1" $component_path

ipx::unload_core $component_path
ipx::open_ipxact_file $component_path
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::check_integrity -quiet [ipx::current_core]
ipx::archive_core $prj_dir/IP_packager/bsc_ompss_[string tolower $name_IP]_${current_version}.zip [ipx::current_core]

