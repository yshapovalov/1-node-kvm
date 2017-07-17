#!/bin/bash
wget -O - https://repo.saltstack.com/apt/ubuntu/16.04/amd64/latest/SALTSTACK-GPG-KEY.pub | sudo apt-key add -
add-apt-repository http://repo.saltstack.com/apt/ubuntu/16.04/amd64/latest
apt update
apt install -y salt-master salt-minion salt-api python reclass make

rm /etc/salt/minion_id
rm -f /etc/salt/pki/minion/minion_master.pub
echo "id: all01.local" > /etc/salt/minion
echo "master: localhost" >> /etc/salt/minion

[ ! -d /etc/salt/master.d ] && mkdir -p /etc/salt/master.d
cat <<-EOF > /etc/salt/master.d/master.conf
file_roots:
  base:
  - /usr/share/salt-formulas/env
pillar_opts: False
open_mode: True
reclass: &reclass
  storage_type: yaml_fs
  inventory_base_uri: /srv/salt/reclass
ext_pillar:
  - reclass: *reclass
master_tops:
  reclass: *reclass
EOF

[ ! -d /etc/reclass ] && mkdir /etc/reclass
cat <<-EOF > /etc/reclass/reclass-config.yml
storage_type: yaml_fs
pretty_print: True
output: yaml
inventory_base_uri: /srv/salt/reclass
EOF

service salt-master restart
service salt-minion restart

git clone https://gerrit.mcp.mirantis.net/p/salt-models/mcp-virtual-aio.git /srv/salt/reclass
cd /srv/salt/reclass
git clone https://gerrit.mcp.mirantis.net/p/salt-models/reclass-system.git classes/system
ln -s /usr/share/salt-formulas/reclass/service classes/service

export FORMULAS_BASE=https://gerrit.mcp.mirantis.net/salt-formulas
export FORMULAS_PATH=/root/formulas
export FORMULAS_BRANCH=master

mkdir -p ${FORMULAS_PATH}
declare -a formula_services=("linux" "reclass" "salt" "openssh" "ntp" "git" "nginx" "collectd" "sensu" "heka" "sphinx" "mysql" "grafana" "libvirt" "rsyslog" "memcached" "rabbitmq" "apache" "keystone" "glance" "nova" "neutron" "cinder" "heat" "horizon" "ironic" "tftpd-hpa" "bind" "powerdns" "designate")
for formula_service in "${formula_services[@]}"; do
  _BRANCH=${FORMULAS_BRANCH}
    [ ! -d "${FORMULAS_PATH}/${formula_service}" ] && {
      if ! git ls-remote --exit-code --heads ${FORMULAS_BASE}/${formula_service}.git ${_BRANCH};then
        # Fallback to the master branch if the branch doesn't exist for this repository
        _BRANCH=master
      fi
      git clone ${FORMULAS_BASE}/${formula_service}.git ${FORMULAS_PATH}/${formula_service} -b ${_BRANCH}
    } || {
      cd ${FORMULAS_PATH}/${formula_service};
      git fetch ${_BRANCH} || git fetch --all
      git checkout ${_BRANCH} && git pull || git pull;
      cd -
  }
  cd ${FORMULAS_PATH}/${formula_service}
  make install
  cd -
done
