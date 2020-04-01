# OmpSs Manager Sources

HLS sources of the Smart OmpSs Manager (SOM)

### Prerequisites
 - [Git Large File Storage](https://git-lfs.github.com/)

##### Git Large File Storage

This repository uses Git Large File Storage to handle relatively-large files that are frequently updated (i.e. hardware runtime IP files) to avoid increasing the history size unnecessarily.
You must install it so Git is able to download these files.

Follow instructions on their website to install it.
Once installed, enable in in the repository with the following command:
```
git lfs install
```


### CI workflow

##### Pushes to master

The pushes to the master branch of this repo are automatically compiled by Jenkins CI to generate the SOM and POM IPs.  
If the build succeeds, the resulting IPs and resource utilization reports are committed to [develop_ip/som](https://pm.bsc.es/gitlab/ompss-at-fpga/ait/tree/develop_ip/som) and [develop_ip/pom](https://pm.bsc.es/gitlab/ompss-at-fpga/ait/tree/develop_ip/pom) branchs of AIT repo.
Then, the generated commits can be imported into the desired AIT branch by using the `git cherry-pick` command or merging the `develop_ip` branch.
Also, the resource reports are stored into the Grafana data base and they become available in the [Grafana SOM](https://pm.bsc.es/grafana/d/Ou4SuTJZz/som-smart-ompss-manager) page.

##### Merge Requests to master

The Merge Requests that target the master branch are compiled to check their correctness.
Note that the source code is not tested, nor integrated in AIT during this step.
Jenkins CI updates the Merge Request status and checks that some version is being increased.
