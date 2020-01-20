variable name_IP [lindex $argv 0]
variable current_version [lindex $argv 1]
variable previous_version [lindex $argv 2]
variable board_part [lindex $argv 3]
variable root_dir [lindex $argv 4]
variable prj_dir [lindex $argv 5]

variable vivado_version [regsub -all {\.} [version -short] {_}]

# Create project
create_project -force [string tolower $name_IP] -part $board_part

# If exists, add board IP repository
set_property ip_repo_paths "[get_property ip_repo_paths [current_project]] $prj_dir/Vivado_HLS" [current_project]
set_property ip_repo_paths "[get_property ip_repo_paths [current_project]] $prj_dir/Vivado_HLS/extended" [current_project]

# Update IP catalog
update_ip_catalog

if {[catch {source $root_dir/scripts/${name_IP}_bd.tcl}]} {
	error "ERROR: Failed sourcing board base design"
}

generate_target all [get_files  ./[string tolower $name_IP].srcs/sources_1/bd/$name_IP/$name_IP.bd]
make_wrapper -files [get_files ./[string tolower $name_IP].srcs/sources_1/bd/$name_IP/$name_IP.bd] -top
add_files -norecurse ./[string tolower $name_IP].srcs/sources_1/bd/$name_IP/hdl/${name_IP}_wrapper.v

set internal_IP_list [get_bd_cells * -filter {VLNV =~ bsc:ompss:* && VLNV !~ bsc:ompss:Command*}]
set bram_list [regsub -all {/} [get_bd_intf_ports -filter {VLNV =~ xilinx.com:interface:bram_rtl*}] ""]

ipx::package_project -root_dir $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP -vendor bsc -library ompss -taxonomy /BSC/OmpSs -generated_files -import_files -set_current false
ipx::unload_core $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/component.xml
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/component.xml

set_property name [string tolower $name_IP] [ipx::current_core]
set_property version $current_version [ipx::current_core]
set_property display_name $name_IP [ipx::current_core]
set_property description $name_IP [ipx::current_core]
set_property vendor_display_name {Barcelona Supercomputing Center (BSC-CNS)} [ipx::current_core]
set_property company_url https://pm.bsc.es/ompss-at-fpga [ipx::current_core]
set_property supported_families {zynquplus Beta zynq Beta virtex7{xc7vx690tffg1157-2} Beta} [ipx::current_core]

ipx::add_file_group -type utility {} [ipx::current_core]
file copy $root_dir/som_logo.png $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/src/
ipx::add_file $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/src/som_logo.png [ipx::get_file_groups xilinx_utilityxitfiles -of_objects [ipx::current_core]]
set_property type LOGO [ipx::get_files src/som_logo.png -of_objects [ipx::get_file_groups xilinx_utilityxitfiles -of_objects [ipx::current_core]]]

# Add extended_mode parameter to HDL files
exec sed -i s/module\ ${name_IP}\$/\\0\ #(extended_mode=0)/g $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/src/${name_IP}.v
exec sed -i s/${name_IP}\ ${name_IP}_i/parameter\ extended_mode=0\;\\n\\n${name_IP}\ #(.extended_mode(extended_mode))\ ${name_IP}_i/g $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/src/${name_IP}_wrapper.v

# Encapsulate modules' instantiations with conditional generate construct
foreach internal_IP_name $internal_IP_list {
	set internal_IP_name ${name_IP}_[string trimleft $internal_IP_name "/"]_0
	exec cat $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/src/${name_IP}.v | tr \$'\n' \$'\x01' | sed s/${internal_IP_name}\[^\;\]*\;/generate\\x01if(extended_mode)\\x01\\0\\x01endgenerate/g | tr \$'\x01' \$'\n' | tee $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/src/${name_IP}.v > /dev/null
}

update_compile_order -fileset sources_1
ipx::merge_project_changes hdl_parameters [ipx::current_core]

# Add num_accs parameter
variable name_param "num_accs"
ipx::add_user_parameter $name_param [ipx::current_core]
set_property value_resolve_type user [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
ipgui::add_param -name $name_param -component [ipx::current_core]
set_property display_name "Number of accelerators" [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]
set_property tooltip "Number of accelerators to be managed by $name_IP" [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]
set_property value 0 [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_format long [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_validation_type range_long [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 0 [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_validation_range_maximum 16 [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]

# Add num_tc_accs parameter
variable name_param "num_tc_accs"
ipx::add_user_parameter $name_param [ipx::current_core]
set_property value_resolve_type user [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
ipgui::add_param -name $name_param -component [ipx::current_core]
set_property display_name "Number of task-creator accelerators" [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]
set_property tooltip "Number of accelerators with task creating capabilities" [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]
set_property value 0 [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_format long [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_validation_type range_long [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 0 [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_validation_range_maximum 16 [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property enablement_tcl_expr "\$extended_mode==1" [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]

# Add num_tw_accs parameter
variable name_param "num_tw_accs"
ipx::add_user_parameter $name_param [ipx::current_core]
set_property value_resolve_type user [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
ipgui::add_param -name $name_param -component [ipx::current_core] -show_label {true}
set_property display_name "Number of accelerators with taskwait" [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]
set_property tooltip "Number of accelerators with taskwait capabilities" [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]
set_property widget {textEdit} [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]
set_property value 0 [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_format long [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_validation_type range_long [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_validation_range_minimum 0 [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_validation_range_maximum 16 [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property enablement_tcl_expr "\$extended_mode==1" [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]

# Add extended_mode parameter
variable name_param "extended_mode"
set_property value_validation_type list [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
set_property value_validation_list {0 1} [ipx::get_user_parameters $name_param -of_objects [ipx::current_core]]
ipgui::add_param -name $name_param -component [ipx::current_core] -display_name "Enable extended mode" -show_label {true} -show_range {true}
set_property tooltip "Enable Smart OmpSs Manager extended mode features" [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]
set_property widget "checkBox" [ipgui::get_guiparamspec -name $name_param -component [ipx::current_core] ]

foreach bram_intf $bram_list {
	ipx::remove_bus_interface ${bram_intf}_clk [ipx::current_core]
	ipx::remove_bus_interface ${bram_intf}_rst [ipx::current_core]
	ipx::infer_bus_interface "${bram_intf}_addr ${bram_intf}_clk ${bram_intf}_din ${bram_intf}_dout ${bram_intf}_en ${bram_intf}_rst ${bram_intf}_we" xilinx.com:interface:bram_rtl:1.0 [ipx::current_core]
	ipx::associate_bus_interfaces -busif $bram_intf -clock aclk [ipx::current_core]

	ipx::add_bus_parameter MASTER_TYPE [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]
	set_property value BRAM_CTRL [ipx::get_bus_parameters MASTER_TYPE -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
	ipx::add_bus_parameter MEM_WIDTH [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]
	ipx::add_bus_parameter MEM_SIZE [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]

	if {$bram_intf == "cmdInQueue"} {
		set_property value 64 [ipx::get_bus_parameters MEM_WIDTH -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
		set_property value 8192 [ipx::get_bus_parameters MEM_SIZE -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
	} elseif {$bram_intf == "cmdOutQueue"} {
		set_property value 64 [ipx::get_bus_parameters MEM_WIDTH -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
		set_property value 8192 [ipx::get_bus_parameters MEM_SIZE -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
	} elseif {$bram_intf == "accAvailability"} {
		set_property value 64 [ipx::get_bus_parameters MEM_WIDTH -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
		set_property value 128 [ipx::get_bus_parameters MEM_SIZE -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
	} elseif {$bram_intf == "bitInfo"} {
		set_property value 32 [ipx::get_bus_parameters MEM_WIDTH -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
		set_property enablement_dependency "\$extended_mode==1" [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]
	} elseif {[string match "intCmdInQueue_*" $bram_intf]} {
		set_property value 64 [ipx::get_bus_parameters MEM_WIDTH -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
		set_property value 8192 [ipx::get_bus_parameters MEM_SIZE -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
		set_property enablement_dependency "\$extended_mode==1" [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]
	} elseif {$bram_intf == "spawnOutQueue"} {
		set_property value 64 [ipx::get_bus_parameters MEM_WIDTH -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
		set_property value 8192 [ipx::get_bus_parameters MEM_SIZE -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
		set_property enablement_dependency "\$extended_mode==1" [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]
	} elseif {$bram_intf == "twInfo"} {
		set_property value 128 [ipx::get_bus_parameters MEM_WIDTH -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
		set_property value 256 [ipx::get_bus_parameters MEM_SIZE -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
		set_property enablement_dependency "\$extended_mode==1" [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]
	} elseif {$bram_intf == "spawnInQueue"} {
		set_property value 64 [ipx::get_bus_parameters MEM_WIDTH -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
		set_property value 8192 [ipx::get_bus_parameters MEM_SIZE -of_objects [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]]
		set_property enablement_dependency "\$extended_mode==1" [ipx::get_bus_interfaces $bram_intf -of_objects [ipx::current_core]]
	}
}

for {set i 0} {$i < 16} {incr i} {
	set_property enablement_dependency "\$num_accs > $i" [ipx::get_bus_interfaces inStream_$i -of_objects [ipx::current_core]]
	set_property enablement_dependency "\$num_accs > $i" [ipx::get_bus_interfaces outStream_$i -of_objects [ipx::current_core]]
	set_property enablement_dependency "\$num_tc_accs > $i" [ipx::get_bus_interfaces ext_inStream_$i -of_objects [ipx::current_core]]
	set_property enablement_dependency "\$num_tw_accs > $i" [ipx::get_bus_interfaces twOutStream_$i -of_objects [ipx::current_core]]
}

ipgui::remove_page -component [ipx::current_core] [ipgui::get_pagespec -name "Page 0" -component [ipx::current_core]]
ipgui::add_group -name "Extended Mode" -component [ipx::current_core] -display_name "Extended Mode" -parent [ipgui::get_canvasspec -component [ipx::current_core]]

ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "num_accs" -component [ipx::current_core]] -parent [ipgui::get_canvasspec -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 1 [ipgui::get_guiparamspec -name "extended_mode" -component [ipx::current_core]] -parent [ipgui::get_canvasspec -component [ipx::current_core]]
ipgui::move_group -component [ipx::current_core] -order 2 [ipgui::get_groupspec -name "Extended Mode" -component [ipx::current_core]] -parent [ipgui::get_canvasspec -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 0 [ipgui::get_guiparamspec -name "num_tc_accs" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Extended Mode" -component [ipx::current_core]]
ipgui::move_param -component [ipx::current_core] -order 1 [ipgui::get_guiparamspec -name "num_tw_accs" -component [ipx::current_core]] -parent [ipgui::get_groupspec -name "Extended Mode" -component [ipx::current_core]]

set_property previous_version_for_upgrade bsc:ompss:[string tolower $name_IP]:$previous_version [ipx::current_core]
set_property core_revision 1 [ipx::current_core]

foreach hdl_file [glob $prj_dir/IP_packager/${name_IP}_${current_version}_${vivado_version}_IP/src/{{*/*,*}.v}] {
	encrypt -key $root_dir/vivado_keyfile_ver.txt -lang verilog $hdl_file
}

update_compile_order -fileset sources_1
ipx::merge_project_changes files [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::check_integrity -quiet [ipx::current_core]
ipx::archive_core $prj_dir/IP_packager/bsc_ompss_[string tolower $name_IP]_${current_version}.zip [ipx::current_core]