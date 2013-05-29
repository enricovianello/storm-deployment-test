## Instructions

### Installation

To install all the needed packages, as root:

{code}
wget https://raw.github.com/italiangrid/storm-deployment-test/master/testsuite-deployment/testsuite-deployment-script.sh
{code}

Before running the script, set your platform choosing between SL5 or SL6 values:

{code}
export PLATFORM=SL6
{code}

Run the script:

{code}
sh testsuite-deployment-script.sh
{code}

### Use

Login with your user and set the needed environment variables:

{code}
wget https://raw.github.com/italiangrid/storm-deployment-test/master/testsuite-deployment/configure-environment-vars.sh
source configure-environment-vars.sh
{code}

Download the run the storm-testsuite by specifying the hostname of your BackEnd:

{code}
git clone https://github.com/italiangrid/storm-deployment-test.git
cd storm-testsuite
pybot --variable backEndHost:<hostname> tests/
{code}






