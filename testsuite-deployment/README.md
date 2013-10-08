## Instructions

### Installation

To install all the packages needed to run the StoRM-testsuite follow these instructions:

1. Download the installation script:

```bash
wget https://raw.github.com/italiangrid/storm-deployment-test/master/testsuite-deployment/testsuite-deployment-script.sh
```

2. Set your environment variables correctly, by choosing between SL5 or SL6 setup scripts:

```bash
wget https://raw.github.com/italiangrid/storm-deployment-test/master/testsuite-deployment/setup-SL5.sh
source setup-SL5.sh
```
or
```bash
wget https://raw.github.com/italiangrid/storm-deployment-test/master/testsuite-deployment/setup-SL6.sh
source setup-SL6.sh
```

3. Run the script:

```bash
sh testsuite-deployment-script.sh
```

### Use

Create your user and login with it.
Create or make sure that _globus_ directory exists:

```bash
mkdir $HOME/.globus
```

If globus directory exists and contains your personal cert and key, do a backup of them because StoRM-testsuite will overwrite your credentials:

```bash
cp $HOME/.globus/usercert.pem $HOME/.globus/usercert.pem.backup
cp $HOME/.globus/userkey.pem $HOME/.globus/userkey.pem.backup
```

Download the run the storm-testsuite by specifying the hostname of your Backend hostname:

```bash
git clone https://github.com/italiangrid/storm-testsuite.git
cd storm-testsuite
pybot --variable backEndHost:<hostname> tests/
```






