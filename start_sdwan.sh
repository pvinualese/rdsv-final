#!/bin/bash

# Requires the following variables
# KUBECTL: kubectl command
# SDWNS: cluster namespace in the cluster vim
# NETNUM: used to select external networks
# VCPE: "pod_id" or "deploy/deployment_id" of the cpd vnf
# VWAN: "pod_id" or "deploy/deployment_id" of the wan vnf
# REMOTESITE: the "public" IP of the remote site

set -u # to verify variables are defined
: $KUBECTL
: $SDWNS
: $NETNUM
: $VACC
: $VCPE
: $VWAN
: $VCTRL
: $REMOTESITE

if [[ ! $VACC =~ "-accesschart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <access_deployment_id>: $VACC"
    exit 1
fi

if [[ ! $VCPE =~ "-cpechart"  ]]; then
    echo ""       
    echo "ERROR: incorrect <cpe_deployment_id>: $VCPE"
    exit 1
fi

if [[ ! $VWAN =~ "-wanchart"  ]]; then
   echo ""       
   echo "ERROR: incorrect <wan_deployment_id>: $VWAN"
   exit 1
fi

if [[ ! $VCTRL =~ "-ctrlchart"  ]]; then
   echo ""       
   echo "ERROR: incorrect <ctrl_deployment_id>: $VCTRL"
   exit 1
fi


ACC_EXEC="$KUBECTL exec -n $SDWNS $VACC --"
CPE_EXEC="$KUBECTL exec -n $SDWNS $VCPE --"
WAN_EXEC="$KUBECTL exec -n $SDWNS $VWAN --"
CTRL_EXEC="$KUBECTL exec -n $SDWNS $VCTRL --"
CTRL_SERV="${VCTRL/deploy\//}"
WAN_SERV="${VWAN/deploy\//}"

# Router por defecto inicial en k8s (calico)
K8SGW="169.254.1.1"

## 1. Obtener IPs y puertos de las VNFs
echo "## 1. Obtener IPs y puertos de las VNFs"

IPACCESS=`$ACC_EXEC hostname -I | awk '{print $1}'`
echo "IPACCESS = $IPACCESS"

IPCPE=`$CPE_EXEC hostname -I | awk '{print $1}'`
echo "IPCPE = $IPCPE"

IPWAN=`$WAN_EXEC hostname -I | awk '{print $1}'`
echo "IPWAN = $IPWAN"

PORTWAN=`$KUBECTL get -n $SDWNS -o jsonpath="{.spec.ports[0].nodePort}" service $WAN_SERV`
echo "PORTWAN = $PORTWAN"

IPCTRL=`$CTRL_EXEC hostname -I | awk '{print $1}'`
echo "IPCTRL = $IPCTRL"

PORTCTRL=`$KUBECTL get -n $SDWNS -o jsonpath="{.spec.ports[0].nodePort}" service $CTRL_SERV`
echo "PORTCTRL = $PORTCTRL"

## 2. En VNF:cpe agregar un bridge y sus vxlan
echo "## 2. En VNF:cpe agregar un bridge y configurar IPs y rutas"
$CPE_EXEC ip route add $IPWAN/32 via $K8SGW
$CPE_EXEC ip route add $IPCTRL/32 via $K8SGW
$CPE_EXEC ovs-vsctl add-br brwan
$CPE_EXEC ip link add cpewan type vxlan id 5 remote $IPWAN dstport 8741 dev eth0
$CPE_EXEC ovs-vsctl add-port brwan cpewan
$CPE_EXEC ifconfig cpewan up
$CPE_EXEC ip link add sr1sr2 type vxlan id 12 remote $REMOTESITE dstport 8742 dev net$NETNUM
$CPE_EXEC ovs-vsctl add-port brwan sr1sr2
$CPE_EXEC ifconfig sr1sr2 up

## 3. En VNF:wan arrancar controlador SDN"
echo "## 3. En VNF:wan arrancar controlador SDN"

$CTRL_EXEC chmod +x ./qos_simple_switch_13.py
$CTRL_EXEC /usr/local/bin/ryu-manager ryu.app.rest_qos ryu.app.rest_conf_switch  ./qos_simple_switch_13.py ryu.app.ofctl_rest flowmanager/flowmanager.py 2>&1 | tee ryu.log &

## 4. En VNF:wan, VNF:cpe, VNF:access activar el modo SDN del conmutador y crear vxlan
$WAN_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$WAN_EXEC ovs-vsctl set-fail-mode brwan secure
$WAN_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000001
$WAN_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633

$WAN_EXEC ip link add cpewan type vxlan id 5 remote $IPCPE dstport 8741 dev eth0
$WAN_EXEC ovs-vsctl add-port brwan cpewan
$WAN_EXEC ifconfig cpewan up

$CPE_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$CPE_EXEC ovs-vsctl set-fail-mode brwan secure
$CPE_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000002
$CPE_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633

$ACC_EXEC ovs-vsctl set bridge brwan protocols=OpenFlow10,OpenFlow12,OpenFlow13
$ACC_EXEC ovs-vsctl set-fail-mode brwan secure
$ACC_EXEC ovs-vsctl set bridge brwan other-config:datapath-id=0000000000000003
$ACC_EXEC ovs-vsctl set-controller brwan tcp:$IPCTRL:6633


## 5. Aplica las reglas de la sdwan con ryu
echo "## 5. Aplica las reglas de la sdwan con ryu"
RYU_ADD_URL="http://localhost:$PORTCTRL/stats/flowentry/add"
curl -X POST -d @json/from-cpe.json $RYU_ADD_URL
curl -X POST -d @json/to-cpe.json $RYU_ADD_URL
curl -X POST -d @json/broadcast-from-axs.json $RYU_ADD_URL
curl -X POST -d @json/from-mpls.json $RYU_ADD_URL
curl -X POST -d @json/to-voip-gw.json $RYU_ADD_URL
curl -X POST -d @json/sdedge$NETNUM/to-voip.json $RYU_ADD_URL

echo "--"
echo "sdedge$NETNUM: abrir navegador para ver sus flujos Openflow:"
echo "firefox http://localhost:$PORTCTRL/home/ &"


## 6. Aplicar QoS


echo "Aplicando QoS"
$WAN_EXEC ovs-vsctl set-manager ptcp:6633
curl -X PUT -d "\"tcp:$IPWAN:6633\"" http://localhost:$PORTCTRL/v1.0/conf/switches/0000000000000001/ovsdb_addr



sleep 5
echo "Aplicando QoS 2"
curl -X POST -d '{"port_name": "axswan", "type": "linux-htb", "max_rate": "3600000", "queues": [ {"max_rate": "3600000"},{"min_rate": "2200000"}]}' http://localhost:$PORTCTRL/qos/queue/0000000000000001

sleep 3
echo "Aplicando QoS 3"
curl -X POST -d '{"match": {"nw_dst": "10.20.1.2", "nw_proto": "UDP", "udp_dst": "5005"}, "actions":{"queue": "1"}}' http://localhost:$PORTCTRL/qos/rules/0000000000000001

sleep 3
echo "Aplicando QoS 3"
curl -X POST -d '{"match": {"nw_dst": "10.20.2.2", "nw_proto": "UDP", "udp_dst": "5005"}, "actions":{"queue": "1"}}' http://localhost:$PORTCTRL/qos/rules/0000000000000001


sleep 3
echo "Aplicando QoS 4"
curl -X GET http://localhost:$PORTCTRL/qos/rules/0000000000000001
