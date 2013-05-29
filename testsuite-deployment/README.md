## Instructions

### Installation

To install all the needed packages, as root:

```bash
wget https://raw.github.com/italiangrid/storm-deployment-test/master/testsuite-deployment/testsuite-deployment-script.sh
```

Before running the script, set your platform choosing between SL5 or SL6 values:

```bash
export PLATFORM=SL6
```

Run the script:

```bash
sh testsuite-deployment-script.sh
```

### Use

Login with your user.
Create or make sure that _globus_ directory exists:

```bash
mkdir $HOME/.globus
```

If globus directory exists and contains your personal cert and key, do a backup of them because storm-testsuite will overwrite your credentials:

```bash
cp $HOME/.globus/usercert.pem $HOME/.globus/usercert.pem.backup
cp $HOME/.globus/userkey.pem $HOME/.globus/userkey.pem.backup
```

Set the needed environment variables:

```bash
wget https://raw.github.com/italiangrid/storm-deployment-test/master/testsuite-deployment/configure-environment-vars.sh
source configure-environment-vars.sh
```

Download the run the storm-testsuite by specifying the hostname of your BackEnd:

```bash
git clone https://github.com/italiangrid/storm-testsuite.git
cd storm-testsuite
pybot --variable backEndHost:<hostname> tests/
```






