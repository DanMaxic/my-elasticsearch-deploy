#!/usr/bin/env bash

#### EXTERNAL PARAMS
ES_CLUSTER_NAME="myTestCluster"
ES_NODE_TYPE="master data" #data/master/ingest/kibana
ES_MASTER_NODE_COUNT="1"
CLOUDWATCH_LOG_GROUP=""


#### INTERNAL PARAMS PARAMS
JDK_VER="11.0.2"
ELASTIC_VER="6.6.0"

####END PARAMS

########==============================RUN TIME ENV
[[ $ES_NODE_TYPE =~ (^|[[:space:]])"master"($|[[:space:]]) ]] && _is_master="true" || _is_master="false"
[[ $ES_NODE_TYPE =~ (^|[[:space:]])"ingest"($|[[:space:]]) ]] && _is_ingest="true" || _is_ingest="false"
[[ $ES_NODE_TYPE =~ (^|[[:space:]])"data"($|[[:space:]]) ]] && _is_data="true" || _is_data="false"
[[ $ES_NODE_TYPE =~ (^|[[:space:]])"kibana"($|[[:space:]]) ]] && is_kibana="true" || is_kibana="false"

########==============================INSTALLING PREREQUISITES
function installPreReq(){
    echo "±±±±±±±±±±±±±>installPreReq"
    sudo yum update -y && yum install -y nano awslogs jq aws-cli bind-utils python34 gcc
}

function init_logsStream(){
  exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
}

function installJava(){
  wget -O ~/jdk${JDK_VER}.rpm --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie"  \
   https://download.oracle.com/otn-pub/java/jdk/${JDK_VER}+9/f51449fcd52f4d52b93a989c5c56ed3c/jdk-${JDK_VER}_linux-x64_bin.rpm
  yum -y localinstall ~/jdk${JDK_VER}.rpm

}

########==============================INSTALLING ELASTIC REGION
function addDataVolume(){
  echo "do nothing"

}

function installElastic(){
  rpm -i https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTIC_VER}.rpm
  sed -i 's/#MAX_LOCKED_MEMORY=.*$/MAX_LOCKED_MEMORY=unlimited/' /etc/sysconfig/elasticsearch
  chkconfig --add elasticsearch
  systemctl daemon-reload
  cat <<EOF >>/etc/security/limits.conf
# allow user 'elasticsearch' mlockall
elasticsearch soft memlock unlimited
elasticsearch hard memlock unlimited
elasticsearch  -  nofile  65536
EOF
}

function configuringElasticPlugIns(){
  /usr/share/elasticsearch/bin/elasticsearch-plugin install --batch x-pack
  /usr/share/elasticsearch/bin/elasticsearch-plugin install --batch discovery-ec2
}

function configuringElasticJvmOptions(){
  local RAM_SIZE="$(free -g | sed -n 2p | awk '{print $2}')"
  local a=$((RAM_SIZE-2))
  local b=$((RAM_SIZE*4/5))
  local new_size=$(( a<b ? a : b))
  local g="g"
  local xmx="-Xmx$new_size$g"
  local xms="-Xms$new_size$g"
  sed -i "s/^-Xms.*/-Xms${xms}/" /etc/elasticsearch/jvm.options
  sed -i "s/^-Xmx.*/-Xmx${xmx}/" /etc/elasticsearch/jvm.options

}

function configuringElasticYml(){

  cat <<EOF >  /etc/elasticsearch/elasticsearch.yml
cluster.name: ${ES_CLUSTER_NAME}
# NODE CONFIG
node.name: \$\{HOSTNAME\}
node.data: ${_is_data}
node.ingest: ${_is_ingest}
node.master: ${_is_master}

path.data: ${elasticsearch_data_dir}
path.logs: ${elasticsearch_logs_dir}

http.port: 9200

# DISCOVERY
discovery.zen.hosts_provider: ec2
discovery.zen.minimum_master_nodes: 3
#network.host: _ec2:privateIpv4_,localhost
plugin.mandatory: discovery-ec2
cloud.node.auto_attributes: true
cluster.routing.allocation.awareness.attributes: aws_availability_zone
discovery:
    zen.hosts_provider: ec2
    ec2.any_group: true
    ec2.host_type: private_ip
    ec2.tag.ES_Cluster: ${ES_CLUSTER_NAME}
    ec2.availability_zones: ${availability_zones}
    ec2.protocol: http

#gateway.recover_after_nodes: 3
#action.destructive_requires_name: true
xpack.security.enabled: true
xpack.monitoring.elasticsearch.collection.enabled: true
xpack.monitoring.collection.enabled: true
xpack.monitoring.history.duration: 30d
#xpack.graph.enabled: false
#xpack.ml.enabled: false
#xpack.watcher.enabled: false

indices.fielddata.cache.size: 50%
indices.breaker.fielddata.limit: 80%

bootstrap.memory_lock: true
EOF

}

function configureEsService(){
  systemctl enable elasticsearch.service
  sudo service elasticsearch start
}

########==============================INSTALLING KIBANA REGION
function installKibana(){
  rpm -i https://artifacts.elastic.co/downloads/kibana/kibana-${ELASTIC_VER}-x86_64.rpm
  chown kibana:kibana -R /usr/share/kibana/
  chkconfig --add kibana
  systemctl daemon-reload
}

function configureEsKibanaPlugins(){
  /usr/share/kibana/bin/kibana-plugin install x-pack || true
}

function configureKibanaService(){
  systemctl enable kibana.service
  sudo service kibana start
}

function InstallElasticPlugins(){
  if [[ -f /sys/hypervisor/uuid && `head -c 3 /sys/hypervisor/uuid` == "ec2" ]]; then
    sudo bin/elasticsearch-plugin install --batch discovery-ec2
    sudo bin/elasticsearch-plugin install --batch repository-s3
  fi
}

function installPythonEsRally(){
  pip3 install esrally
}

#=============== BASIC ROUTINES

function InstallBasics(){
  installPreReq
  installJava
  installKibana
#  installElastic
}



#===============
function installClient(){

}
function installMaster(){

}
function installDataNode(){

}
function installingestNode(){

}

function insallNode(){
  InstallBasics
  if [ "true" == "${data}" ]; then

  fi
}
#===============

function main(){
  init_logsStream
}

main