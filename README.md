StoRM-deployment-test
=====================

A collection of useful scripts to automatic install StoRM components.

You can deploy on a single host a EMI2/EMI3 StoRM full installation, configured, as default, to be tested with [StoRM-testsuite](https://github.com/italiangrid/storm-testsuite).

### Instructions

Using these scripts is very simple. First of all you have to download the appropriate _setup-script_, choosing between:

* EMI3 StoRM (stable) - [SL5](https://raw.github.com/italiangrid/storm-deployment-test/master/setup-scripts/SL5/setup-emi3-sl5.sh) [SL6](https://raw.github.com/italiangrid/storm-deployment-test/master/setup-scripts/SL6/setup-emi3-sl6.sh)
* EMI3 StoRM from developers repo (unstable) - [SL5](https://raw.github.com/italiangrid/storm-deployment-test/master/setup-scripts/SL5/setup-emi3-devel-sl5.sh) [SL6](https://raw.github.com/italiangrid/storm-deployment-test/master/setup-scripts/SL6/setup-emi3-devel-sl6.sh)
* EMI2 StoRM (stable) - [SL5](https://raw.github.com/italiangrid/storm-deployment-test/master/setup-scripts/SL5/setup-emi2-sl5.sh) [SL6](https://raw.github.com/italiangrid/storm-deployment-test/master/setup-scripts/SL6/setup-emi2-sl6.sh)

or building it on your own, knowing that the available variables are the following:

* ADDITIONAL\_REPO: the URI of a different repo to add for StoRM and EMI components installation
* EMI\_RELEASE\_REMOTE\_RPM (**mandatory**): the URI of the EMI release rpm
* EPEL\_RELEASE\_REMOTE\_RPM (**mandatory**): the URI of the EPEL release rpm
* YAIM\_CONFIGURATION\_FILE: the URI of the _storm.def_ file with YAIM configuration values
* REQUIRED\_STORM\_UID: the required user-id of _storm_ user
* REQUIRED\_STORM\_GID: the required user-gid for storm user
* IGI\_TEST\_CA\_REMOTE\_RPM: the URI of the IGI-test-CA rpm
* EGI\_TRUSTANCHORS\_REPO: the URI of the EGI-trustanchors repo
* JAVA\_LOCATION: a different java location
* FS\_TYPE: values are "DISK" or "GPFS" (default: DISK)

Then, launch the deployment script.

So, for example, to deploy the latest EMI3 StoRM packages on a SL6 you had to do these following commands:

	wget https://raw.github.com/italiangrid/storm-deployment-test/master/setup-scripts/SL6/setup-emi3-devel-sl6.sh
	source setup-emi3-devel-sl6.sh
	wget https://raw.github.com/italiangrid/storm-deployment-test/master/emi-storm-clean-deployment.sh
	sh emi-storm-clean-deployment.sh
