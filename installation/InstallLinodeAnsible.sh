set -x

BUILD_HOME="`/bin/cat /home/buildhome.dat`"

if ( [ ! -d ${BUILD_HOME}/runtime/ansible-env ] )
then
        /bin/mkdir -p ${BUILD_HOME}/runtime/ansible-env
fi

python_version="`python3 --version | /usr/bin/awk '{print $NF}' | cut -d. -f1,2`"

apt update
apt install python${python_version}-venv

# 1. Create a virtual environment (e.g., named 'ansible-env')
python3 -m venv ${BUILD_HOME}/runtime/ansible-env

# 2. Activate the virtual environment
. ${BUILD_HOME}/runtime/ansible-env/bin/activate

# 3. Upgrade pip and install the requirements securely
pip install --upgrade pip

/usr/bin/wget https://raw.githubusercontent.com/linode/ansible_linode/main/requirements.txt -O ${BUILD_HOME}/runtime/ansible-env/requirements.txt

if [ $? -eq 0 ]
then
        cat << 'EOF' > "${BUILD_HOME}/runtime/ansible-env/requirements.txt"
linode_api4>=5.46.1
polling==0.3.2
ansible-specdoc>=0.0.20
EOF
fi

pip install --upgrade -r ${BUILD_HOME}/runtime/ansible-env/requirements.txt
