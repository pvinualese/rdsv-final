FROM      osrg/ryu

RUN apt-get clean
RUN	apt-get update && apt-get install -y \
	net-tools \
	iproute \
	inetutils-ping \
    openvswitch-switch \
    openvswitch-common \
    iperf \
    tcpdump \
    python-pip \
    git

#RUN pip install -r ryu/tools/optional-requires
RUN git clone https://github.com/martimy/flowmanager

COPY README.txt /app/README.txt
COPY qos_simple_switch_13.py /root/qos_simple_switch_13.py


# Comando para iniciar el controlador Ryu y el script QoS
CMD ["ryu-manager", "ryu.app.rest_qos", "ryu.app.rest_conf_switch", "/root/qos_simple_switch_13.py"]