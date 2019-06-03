variable name_IP Command_TM
variable num_version 1.0
variable vivado_version 16_3
variable board_part xczu9eg-ffvc900-1-e-es2

cd ompss_manager_IP/Vivado/command_tm

# Create project
create_project -force [string tolower $name_IP] -part $board_part

# If exists, add board IP repository
set_property ip_repo_paths [list [get_property ip_repo_paths [current_project]] ../../Vivado_HLS] [current_project]
#if {[file isdirectory $path_Project/$board/ipdefs/]} {
#    set_property ip_repo_paths [list [get_property ip_repo_paths [current_project]] $path_Project/$board/ipdefs] [current_project]
#    update_ip_catalog
#    foreach {IP} [glob -nocomplain $path_Project/$board/ipdefs/*.zip] {
#        update_ip_catalog -add_ip $IP -repo_path $path_Project/$board/ipdefs
#    }
#}

# Update IP catalog
update_ip_catalog

if {[catch {source -notrace ../../../scripts/task_manager_bd.tcl}]} {
	error "\[autoVivado\] ERROR: Failed sourcing board base design"
}

generate_target all [get_files  ./[string tolower $name_IP].srcs/sources_1/bd/$name_IP/$name_IP.bd]
make_wrapper -files [get_files ./[string tolower $name_IP].srcs/sources_1/bd/$name_IP/$name_IP.bd] -top
add_files -norecurse ./[string tolower $name_IP].srcs/sources_1/bd/$name_IP/hdl/${name_IP}_wrapper.v

#source ./task_manager_bd.tcl

set bram_list [regsub -all {/} [get_bd_intf_ports -filter {VLNV =~ xilinx.com:interface:bram_rtl*}] ""]

ipx::package_project -root_dir ../../IP_packager/${name_IP}_${num_version}_${vivado_version}_IP -vendor bsc -library ompss -taxonomy /BSC/OmpSs -generated_files -import_files -set_current false
ipx::unload_core ../../IP_packager/${name_IP}_${num_version}_${vivado_version}_IP/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory ../../IP_packager/${name_IP}_${num_version}_${vivado_version}_IP ../../IP_packager/${name_IP}_${num_version}_${vivado_version}_IP/component.xml

set_property name [string tolower $name_IP] [ipx::current_core]
set_property version $num_version [ipx::current_core]
set_property display_name $name_IP [ipx::current_core]
set_property description $name_IP [ipx::current_core]
set_property vendor_display_name {Barcelona Supercomputing Center (BSC-CNS)} [ipx::current_core]
set_property company_url https://pm.bsc.es/ompss-at-fpga [ipx::current_core]
set_property supported_families {zynquplus Beta zynq Beta} [ipx::current_core]

# Add num_accs parameter
variable name_param "num_accs"
ipx::add_user_parameter $name_param [ipx::current_core]
set_property value_resolve_type user [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
ipgui::add_param -name $name_param -component [ipx::current_core]
set_property display_name {Number of accelerators} [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]
set_property tooltip "Number of accelerators to be managed by $name_IP" [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]
set_property value 1 [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_format long [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_validation_type range_long [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 1 [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_validation_range_maximum 16 [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]

foreach bram_intf $bram_list {
	ipx::remove_bus_interface ${bram_intf}_clk [ipx::current_core]
	ipx::remove_bus_interface ${bram_intf}_rst [ipx::current_core]
	ipx::infer_bus_interface "${bram_intf}_addr ${bram_intf}_clk ${bram_intf}_din ${bram_intf}_dout ${bram_intf}_en ${bram_intf}_rst ${bram_intf}_we" xilinx.com:interface:bram_rtl:1.0 [ipx::current_core]
	ipx::associate_bus_interfaces -busif $bram_intf -clock aclk [ipx::current_core]

	ipx::add_bus_parameter MASTER_TYPE [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]
	set_property value BRAM_CTRL [ipx::get_bus_parameters MASTER_TYPE -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
	ipx::add_bus_parameter MEM_SIZE [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]
	set_property value 16384 [ipx::get_bus_parameters MEM_SIZE -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
	ipx::add_bus_parameter MEM_WIDTH [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]
	set_property value 128 [ipx::get_bus_parameters MEM_WIDTH -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
}

for {set i 0} {$i < 16} {incr i} {
		set_property enablement_dependency "\$num_accs > $i" [ipx::get_bus_interfaces *Stream_$i -of_objects [ipx::current_core]]
}

ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "num_accs" -component [ipx::current_core]] -parent [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
set_property previous_version_for_upgrade bsc:ompss:[string tolower $name_IP]:1.0 [ipx::current_core]
set_property core_revision 1 [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::check_integrity -quiet [ipx::current_core]
ipx::archive_core ../../IP_packager/${name_IP}_${num_version}_${vivado_version}_IP/bsc_ompss_[string tolower $name_IP]_${num_version}.zip [ipx::current_core]
