#!/bin/bash

exec > /var/log/user-data.log 2>&1
set -x
echo "User data script started"

set -e

sudo yum update -y
sudo yum install -y git

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install node  # Install the latest LTS version
nvm use node

git clone -b main https://github.com/tristenkelly/infra-demo /home/ec2-user/app
cd /home/ec2-user/app

npm install
npm install express  # Ensure express is installed

pm2 start index.js --name my-app

rm -rf /home/ec2-user/app

#!/bin/bash

# ...rest of your script...
echo "User data script finished"