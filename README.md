# OmpSs Manager Sources

HDL sources of the Picos OmpSs Manager (POM)

### CI workflow

##### Pushes to master

The pushes to the master branch of this repo are automatically compiled by Jenkins CI to generate the POM IP.  
If the build succeeds, the resulting IPs and resource utilization reports are committed to [develop_ip/pom](https://pm.bsc.es/gitlab/ompss-at-fpga/ait/tree/develop_ip/pom) branch of AIT repo.
Then, the generated commits can be imported into the desired AIT branch by using the `git cherry-pick` command or merging the `develop_ip` branch.
Also, the resource reports are stored into the Grafana data base and they become available in the [Grafana POM](https://pm.bsc.es/grafana/d/Ou4SuTJZz/ompss-manager-resources) page.

##### Merge Requests to master

The Merge Requests that target the master branch are compiled to check their correctness.
Note that the source code is not tested, nor integrated in AIT during this step.
Jenkins CI updates the Merge Request status and checks that some version is being increased.
