#!/bin/bash

if [[ -z $1 ]]; then
	t_mode="interactive"
else
	t_mode=$1
fi

function simpleRND2 {
	rnd_from=1
	rnd_to=200

	if [[ ! -z "$1" && -z "$2" ]]
		then rnd_from=$1
	fi

	if [[ ! -z "$1" && ! -z "$2" ]]
	then
		rnd_from=$1
		rnd_to=$2			
	fi

	my_rnd=$(($rnd_from+RANDOM%($rnd_to-$rnd_from+1)))
}

function getVMName {
t_hostname=$(hostname)
if [ -f ./vps_name.var ]; then
	read VM_NAME < ./vps_name.var
else
	if [[ $t_mode == "interactive" ]]; then
		read -p "Enter VM name, [ENTER] set to default: ${t_hostname}: " VM_NAME
		if [ -z $VM_NAME ]; then
			VM_NAME=$t_hostname
		fi
		echo $VM_NAME > ./vps_name.var
	else
		VM_NAME=$t_hostname
	fi
fi
}

function archDockerSource {
mydockfile="${VM_NAME}_docker_source_${mydate}".tar.gz
source_bu_path=""
for i in `docker ps --format '{{.Names}}'`
do 
	dock_name=$(docker inspect $i | grep '"Source":' | awk '{print $2}' | sed 's/"//g' | sed 's/,//')
	source_bu_path="${dock_name} ${source_bu_path}" 
done
tar -czf /backup/$mydockfile $source_bu_path
}

function checkDockerInstalled() {
dock_ver=$(docker -v 2>/dev/null | cut -d ' ' -f 3 | tr -d ',')

if [ -z $dock_ver ]; then
	dock_inst=0
else
	dock_inst=1
fi
}

function checkNFSMount {
mount_line=$(df -h | grep VPSBackup)
if [[ ! -z $mount_line ]]; then
	nfs_mount=1
else
	nfs_mount=0
fi
}

function checkPrivNetAvailable {
p_loss=$(ping -qw 3 192.168.10.10 2>/dev/null | grep 'packet loss' | cut -d ' ' -f 6 | sed 's/%//')
if [[ $p_loss -eq 100 ]]; then
	net_avail=0
else
	net_avail=1
fi
}

function checkFSTab {
fstab_line=$(grep VPSBackup /etc/fstab)
if [[ ! -z $fstab_line ]]; then
	fstab_in=1
else
	fstab_in=0
fi
}

function mountNFSBackup {
checkNFSMount
if [[ $nfs_mount -eq 0 ]]; then
	checkPrivNetAvailable
	if [[ $net_avail -eq 1 ]]; then
		checkFSTab
		if [[ $fstab_in -eq 1 ]]; then
			mount /mnt/backup
		else
			mount -o rw 192.168.10.10:/volume1/VPSBackup /mnt/backup
		fi
		
		checkNFSMount
		if [[ $nfs_mount -eq 1 ]]; then
			mount_success=1
			echo "NFS backup folder mounted successfully" >> ~/backup.log
		else
			mount_success=0
			echo "NFS backup folder not mounted" >> ~/backup.log
		fi
	else
		mount_success=0
		echo "NFS backup folder not mounted" >> ~/backup.log
	fi
else
	mount_success=1
	echo "NFS backup folder mounted successfully" >> ~/backup.log
fi
}

function checkFreeDiskSpace {
free_space_min=500
free_spase_meg=$(df -m / | awk '{print $4}' | grep -iv avail)
if [[ $free_spase_meg -lt $free_space_min ]]; then
	low_disk_space=1
else
	low_disk_space=0
fi
}

function configCrontab2() {
local exe_str="/root/backup/my_backup_launcher.sh"
checkCrontab

if [[ $cron_conf2 -eq 1 ]]; then
	# cronMenu
	# if [[ $delete_cron -eq 1 ]]; then
		# delCron
		# return
	# elif [[ $reconfig_cron -eq 0 ]]; then
		# return
	# fi
	return
else
	# read -p "Configure Crontab for WG repair? [Y/n]: " cron
	# if [[ -z $cron ]]; then
		# cron='Y'
	# fi

	# until [[ "$cron" =~ ^[yYnN]*$ ]]; do
		# echo "$cron: invalid selection."
		# read -p "Configure Crontab? [y/n]: " cron
	# done
	cron="Y"
fi

if [[ $cron_conf -eq 1 ]]; then
	grep -v $exe_str /var/spool/cron/crontabs/root | grep -v '^#' | grep -v '^$' > mycron
fi

if [[ "$cron" =~ ^[yY]$ ]]; then
	checkPrepare
	
	simpleRND2 0 6
	t_week_day=$my_rnd
	
	simpleRND2 0 23
	t_hour=$my_rnd
	
	simpleRND2 0 59
	t_minute=$my_rnd
	
	cron_time_str="${t_minute} ${t_hour} * * ${t_week_day}"
	echo "${cron_time_str}  ${exe_str}" >> mycron
	crontab mycron
	rm mycron 
	
	# echo "Crontab configured"
	# crontab -l
fi
}

function delCron {
local exe_str="/root/backup/my_backup_launcher.sh"

grep -v $exe_str /var/spool/cron/crontabs/root | grep -v '^#' | grep -v '^$' > mycron
cron_line_num=$(cat mycron | wc -l)
if [[ $cron_line_num -eq 0 ]]; then
	crontab -r
else
	crontab mycron
fi
rm mycron
}

function checkCrontab() {
local exe_str="/root/backup/my_backup_launcher.sh"
if [ -f /var/spool/cron/crontabs/root ]; then
	cron_conf=1
	cron_line=$(grep "$exe_str" /var/spool/cron/crontabs/root)
	if [[ ! -z $cron_line ]]
		then cron_conf2=1
	fi
else
	cron_conf=0
	cron_conf2=0
fi
}

function checkPrepare() {
if [ ! -d ~/backup ]; then
	mkdir ~/backup
fi

if [[ ! -f ~/backup/my_backup_launcher.sh ]]; then
	if [[ ! -f my_backup_launcher.sh ]]; then
		wget https://github.com/Paulus13/my_backup/raw/main/my_backup_launcher.sh
	fi
	mv my_backup_launcher.sh ~/backup
	chmod +x ~/backup/my_backup_launcher.sh
else
	chmod +x ~/backup/my_backup_launcher.sh
fi
}

function cronMenu() {
	MENU_OPTION="menu"
	# echo
	# echo "Crontab menu"
	echo 
	echo "What do you want to do?"
	echo "   1) Reconfigure crontab for WG repair"
	echo "   2) Delete crontab configuration for WG repair"
	echo "   3) Do Nothing"
	# until [[ -z $MENU_OPTION || $MENU_OPTION =~ ^[1-3]$ ]]; do
	until [[ $MENU_OPTION =~ ^[1-3]$ ]]; do
		read -rp "Select an option [1-3]: " MENU_OPTION
	done

	case $MENU_OPTION in
	1)
		reconfig_cron=1
		delete_cron=0
		;;
	2)
		reconfig_cron=1
		delete_cron=1
		;;
	3)
		reconfig_cron=0
		delete_cron=0
		;;		
	esac
}

# edit this variable, enter understandable VM name
# VM_NAME=$(hostname)

getVMName

mydate=$(date '+%Y-%m-%d_%H-%M-%S')
myfile1="${VM_NAME}_${mydate}".tar.gz

my_home=~
my_home2=$(echo $my_home | grep "/home")

if [[ -z $my_home2 ]]; then
	# root home
	home_path="${my_home} /home"
else
	# non root home
	home_path="${my_home}"
fi

if [ -f ~/backup.log ]; then
	rm ~/backup.log
fi

if [ ! -d /backup ]; then
	mkdir /backup
fi

checkFreeDiskSpace
old_arch_line=$(ls /backup/*.tar.gz 2>/dev/null)
if [[ $low_disk_space -eq 1 ]]; then
	if [[ ! -z $old_arch_line ]]; then
		mountNFSBackup
		if [[ $mount_success -eq 1 ]]; then
			mkdir -p /mnt/backup/${VM_NAME}
			mv /backup/*.tar.gz /mnt/backup/${VM_NAME}
			echo "Low disk space detected, all previous backup archives moved to mounted NFS Backup Folder" >> ~/backup.log
		else
			rm -f /backup/*.tar.gz
			echo "Low disk space detected, all previous backup archives removed" >> ~/backup.log	
		fi
	fi
fi

# check SE
if [ -f /lib/systemd/system/softether-vpnserver.service ]; then
	se=1
	if [ -d /var/log/softether/security_log ]; then
		#Installed from repo
		echo "SE installed from repository" >> ~/backup.log
		#se_path="/usr/bin/vpn* /usr/vpn* /var/log/softether/ /usr/libexec/softether/vpnserver /lib/systemd/system/isc-dhcp-server.service /lib/systemd/system/softether-vpnserver.service"
		#se_path="/usr/bin/vpn* /usr/vpn* /usr/libexec/softether/vpnserver /lib/systemd/system/isc-dhcp-server.service /lib/systemd/system/softether-vpnserver.service /var/lib/softether"
		se_path="/usr/bin/vpn* /usr/libexec/softether/vpnserver /lib/systemd/system/isc-dhcp-server.service /lib/systemd/system/softether-vpnserver.service /var/lib/softether"
	fi
	
	if [ -d /usr/vpnserver/security_log ]; then
		#Compiled from source, default path
		echo "SE bult from source, default path" >> ~/backup.log
		se_path="/usr/bin/vpn* /usr/vpn* /usr/libexec/softether/vpnserver /lib/systemd/system/isc-dhcp-server.service /lib/systemd/system/softether-vpnserver.service"
	fi
	
	if [ -d /usr/local/softether/vpnserver/security_log ]; then
		#Compiled from source, Philipp change path
		echo "SE bult from source, changed path"  >> ~/backup.log
		se_path="/usr/local/bin/vpn* /usr/local/softether/ /lib/systemd/system/isc-dhcp-server.service /lib/systemd/system/softether-vpnserver.service"
	fi
	
	# Remove SE source
	if [ -d /root/*/v4.38-9760 ]; then
		rm -rf /root/*/v4.38-9760
	fi

	if [ -d /root/*/SoftEtherVPN_Stable-master ]; then
		rm -rf /root/*/SoftEtherVPN_Stable-master
	fi
	
	if [ -d /home/*/*/v4.38-9760 ]; then
		rm -rf /home/*/*/v4.38-9760
	fi

	if [ -d /home/*/*/SoftEtherVPN_Stable-master ]; then
		rm -rf /home/*/*/SoftEtherVPN_Stable-master
	fi
else
	se=0
fi

# check OVPN
if [ -f /lib/systemd/system/openvpn-server@.service ]; then
	ovpn=1
	echo "OpenVPN installed"  >> ~/backup.log
	ovpn_path1="${my_home}/EasyRSA/"
	ovpn_path2="${my_home}/client-configs/"
	ovpn_path3="/etc/openvpn/server/"
	#ovpn_path="${ovpn_path1} ${ovpn_path2} ${ovpn_path3}"
	ovpn_path="${ovpn_path3}"
else
	ovpn=0
fi

# check Swan
if [ -f /lib/systemd/system/strongswan-starter.service ]; then
	swan=1
	echo "StrongSwan installed" >> ~/backup.log
	swan_path1="${my_home}/pki/"
	swan_path2="/etc/ipsec.* /etc/strongswan.d/ /etc/apparmor.d/usr.lib.ipsec.charon"
	#swan_path="${swan_path1} ${swan_path2}"
	swan_path="${swan_path2}"
else
	swan=0
fi

# check WG
if [ -f /lib/systemd/system/wg-quick@.service ]; then
	wg2=1
	echo "Wireguard installed" >> ~/backup.log
	wg_path="/etc/wireguard/"
else
	wg2=0
fi

# check F2B
if [ -f /lib/systemd/system/fail2ban.service ]; then
	f2b=1
	echo "Fail2Ban installed" >> ~/backup.log
	f2b_path="/etc/fail2ban/"
else
	f2b=0
fi

# check Iptables-persistent
if [ -f /lib/systemd/system/netfilter-persistent.service ]; then
	iptp=1
	echo "Iptables-persistent installed" >> ~/backup.log
	iptp_path="/etc/iptables/"
else
	iptp=0
fi

# check Bind
if [ -f /lib/systemd/system/named.service ]; then
	bind09=1
	echo "Bind installed" >> ~/backup.log
	bind_path="/etc/bind/"
else
	bind09=0
fi

# check Unbound
if [ -f /lib/systemd/system/unbound.service ]; then
	unb=1
	echo "Unbound installed" >> ~/backup.log
	unb_path="/etc/unbound/"
else
	unb=0
fi

# check obsolete firewall service
if [ -f /etc/systemd/system/firewall.service ]; then
	ofw=1
	echo "Obsolete firewall service used. Iptables rules saved to rules.v4 file" >> ~/backup.log
	ofw_path="/etc/systemd/system/firewall.service /etc/firewall.sh /etc/firewall-clear.sh"
	iptables-save | grep -v f2b > ~/rules.v4
else
	ofw=0
fi

# check crontab
if [ -f /var/spool/cron/crontabs/root ]; then
	cron2=1
	echo "Crontab used"  >> ~/backup.log
	cron_path="/var/spool/cron/crontabs/root"
else
	cron2=0
fi

# check SWGP
if [ -f /lib/systemd/system/swgp-go.service ]; then
	swgp2=1
	echo "SWGP used"  >> ~/backup.log
	swgp_path1="/etc/swgp-go/"
	swgp_path2="/usr/bin/swgp-go"
	swgp_path3="/lib/systemd/system/swgp-go.service"
	swgp_path="${swgp_path1} ${swgp_path2} ${swgp_path3}"
else
	swgp2=0
fi

# check DNS Proxy
if [ -f /etc/systemd/system/dnsproxy.service ]; then
	dns_proxy=1
	echo "DNS Proxy used"  >> ~/backup.log
	dproxy_path1="/usr/bin/dnsproxy"
	dproxy_path2="/etc/systemd/system/dnsproxy.service"
	dproxy_path="${dproxy_path1} ${dproxy_path2}"
else
	dns_proxy=0
fi

# check Docker
checkDockerInstalled
if [[ $dock_inst -eq 1 ]]; then
	dock_num=$(docker ps -a | wc -l)
	dock_3xui=$(docker ps -a | grep 3x-ui)
	dock_shadow=$(docker ps -a | grep shadowbox)
	
	if [[ $dock_num -gt 0 ]]; then
		docker_used=1
		echo "Docker used"  >> ~/backup.log
		if [[ ! -z $dock_3xui ]]; then
			echo "	3x-ui docker image present"  >> ~/backup.log
		fi
		if [[ ! -z $dock_shadow ]]; then
			echo "	shadowbox docker image present"  >> ~/backup.log
		fi		
		archDockerSource
		echo "Docker Sources archive file: ${mydockfile}"  >> ~/backup.log
	fi
else
	docker_used=0
fi

t_home_line=$(ls /home/)
if [[ ! -z $t_home_line ]]; then
	cat /etc/passwd | grep $(ls /home) > ~/my_passwd
	cat /etc/shadow | grep $(ls /home) > ~/my_shadow
fi

#common_path="/etc/ssh/sshd_config /home/"
common_path="/etc/ssh/sshd_config /etc/sysctl.conf"

bu_path="${se_path} ${ovpn_path} ${swan_path} ${wg_path} ${f2b_path} ${iptp_path} ${ofw_path} ${bind_path} ${unb_path} ${cron_path} ${swgp_path} ${dproxy_path} ${common_path} ${home_path}"

#echo $myfile1

echo >> ~/backup.log
echo "Path to backup:" >> ~/backup.log
echo $bu_path >> ~/backup.log

#sudo tar -czf /backup/$myfile1 /etc/wireguard /home/user /root /etc/ntp.conf /etc/firewall* /etc/systemd/system/firewall.service > /dev/null

echo >> ~/backup.log
echo "Exclude:" >> ~/backup.log
echo "--exclude='*/server_log/*' --exclude='*.gz' --exclude='*.deb' --exclude='*/*/softether/*' --exclude='/*/*/se/*' --exclude='*/softether/*' --exclude='*/se/*' --exclude='.cache/*' --exclude='go*' --exclude='*/3x-ui/*' --exclude='*/dnsproxy/*' --exclude='*/packet_log/*'" >> ~/backup.log

sudo tar --exclude='*/server_log/*' --exclude='*.gz' --exclude='*.deb' --exclude='*/*/softether/*' --exclude='/*/*/se/*' --exclude='*/softether/*' --exclude='*/se/*' --exclude='.cache/*' --exclude='go*' --exclude='*/3x-ui/*' --exclude='*/dnsproxy/*' --exclude='*/packet_log/*' -czf /backup/$myfile1 $bu_path > /dev/null
tar_rc=$?

echo >> ~/backup.log
echo "TAR_RC: ${tar_rc}" >> ~/backup.log

if [ "$tar_rc" = "0" ]; then
	echo "Success" >> ~/backup.log
else
	echo "Errors orrured" >> ~/backup.log
fi

mountNFSBackup
if [[ $mount_success -eq 1 ]]; then
	mkdir -p /mnt/backup/${VM_NAME}
	mv /backup/$myfile1 /mnt/backup/${VM_NAME}
	echo "Main archive moved to mounted backup folder" >> ~/backup.log
	if [[ ! -z $mydockfile ]]; then
		mv /backup/$mydockfile /mnt/backup/${VM_NAME}
		echo "Docker archive moved to mounted backup folder" >> ~/backup.log	
	fi
fi

mv ~/backup.log ~/backup_${mydate}.log

configCrontab2

#sudo -u bu scp /backup/$myfile1 bu@10.50.0.5:/home/bu/backup/boodet
#cp /backup/$myfile1 /home/bu/backup/boodet/
#scp_rc=$?
#echo $mydate  TAR_RC=$tar_rc  SCP_RC=$scp_rc >> /backup/backup.log