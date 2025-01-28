# Paquetes e imagenes
cd ~/helm-files
helm package ~/shared/rdsv-final/helm/accesschart
helm package ~/shared/rdsv-final/helm/cpechart
helm package ~/shared/rdsv-final/helm/wanchart
helm package ~/shared/rdsv-final/helm/cpechart
helm package ~/shared/rdsv-final/helm/ctrlchart
helm repo index --url http://127.0.0.1/ .
cat index.yaml
docker stop helm-repo
docker rm helm-repo
docker run --restart always --name helm-repo -p 8080:80 -v ~/helm-files:/usr/share/nginx/html:ro -d nginx
curl http://127.0.0.1:8080/index.yaml
# EJECUCION FICHEROS INICIAL

DENTRO DE shred/rdsv-final:

- ./sdedge1.sh
- ./sdedge2.sh
- ./sdwan1.sh
- ./sdwan2.sh

## Abrir las consolas de las 4 KNFs

bin/sdw-knf-consoles open 1

## Arrancar escenario para abrir todas las consolas

cd vnx
sudo vnx -f sdedge_nfv.xml --destroy
sudo vnx -f sdedge_nfv.xml -t

## QoS

Abrir consolas de h1, h2 y voip-gw
- h1:  iperf -s -u -i 1 -p 5005
- h2:  iperf -s -u -i 1 -p 5005
- voip-gw: iperf -c 10.20.1.2 -p 5005 -u -b 5M -l 1200
- voip-gw: iperf -c 10.20.2.2 -p 5005 -u -b 5M -l 1200

## ARP 


systemctl restart arpwatch
sudo ls /var/lib/arpwatch/   (se muestra solo el fichero ethercodes.db)
sudo touch /var/lib/arpwatch/arp.dat
sudo chmod 664 /var/lib/arpwatch/arp.dat
sudo chown nobody:nogroup /var/lib/arpwatch/arp.dat

sudo arpwatch -d -i eth1

sudo tcpdump -i eth1 arp



Otros que probablemente no valgan:

- Borrar entrada: sudo arp -d 10.20.2.2
- ver tabla: arp -n

arpwatch -i eth1

sudo nano /lib/systemd/system/arpwatch.service
ExecStart=/usr/sbin/arpwatch -i eth1 -f /var/lib/arpwatch/arp.dat

sudo systemctl daemon-reload
sudo systemctl restart arpwatch

sudo tail -f /var/log/syslog




