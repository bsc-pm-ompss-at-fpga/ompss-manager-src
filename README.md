# OmpSs Manager Sources

HLS sources of the OmpSs Manager

### CI workflow

The pushes to the master branch of this repo are automatically compiled by jenkins CI.  
If the build succeeds, the resulting IP zips and resource utilization report are committed to the [develop/ip_defs](https://pm.bsc.es/gitlab/ompss-at-fpga/autoVivado/tree/develop/ip_defs) branch of autoVivado repo.
Then, the generated commit can be imported into the desired autoVivado branch by using the `git cherry-pick` command.
