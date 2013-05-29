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

Login with your user and set the needed environment variables:

```bash
wget https://raw.github.com/italiangrid/storm-deployment-test/master/testsuite-deployment/configure-environment-vars.sh
source configure-environment-vars.sh
```

Download the run the storm-testsuite by specifying the hostname of your BackEnd:

```bash
git clone https://github.com/italiangrid/storm-deployment-test.git
cd storm-testsuite
pybot --variable backEndHost:<hostname> tests/
```






