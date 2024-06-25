#!/bin/bash

script_path_share="/mnt/backup/scripts"
script_name_share="my_backup_v3.sh"
script_full_path_share="${script_path_share}/${script_name_share}"

script_launcher_name_share="my_backup_launcher.sh"
script_launcher_full_path_share="${script_path_share}/${script_launcher_name_share}"

script_path_local="/root/backup"
script_name_local="my_backup_v3.sh"
script_full_path_local="${script_path_local}/${script_name_local}"
# exec_line="${script_full_path_local} cron"

script_launcher_name_local="my_backup_launcher.sh"
script_launcher_full_path_local="${script_path_local}/${script_launcher_name_local}"
exec_line="${script_launcher_full_path_local}"

log_path_local="/root/backup"
log_file_local="${log_path_local}/updater.log"
log_file_tmp="${log_path_local}/tmp.log"

function checkNeededSoft() {
md5sum_ver=$(md5sum --version 2>/dev/null)
# bc_ver=$(bc --version 2>/dev/null)
# wget_ver=$(wget --version 2>/dev/null)
# tar_ver=$(tar --version 2>/dev/null)
# git_ver=$(git --version 2>/dev/null)
# curl_ver=$(curl --version 2>/dev/null)
# ipt_ver=$(iptables --version 2>/dev/null)

# if [[ -z $bc_ver || -z $wget_ver || -z $tar_ver || -z $git_ver || -z $curl_ver || -z $ipt_ver ]]; then
if [[ -z $md5sum_ver ]]; then
	apt update
	# apt install -y bc wget tar git curl iptables
	apt install -y coreutils
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

function checkNFSMount {
mount_line=$(df -h | grep VPSBackup)
if [[ ! -z $mount_line ]]; then
	nfs_mount=1
else
	nfs_mount=0
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
			# echo "NFS backup folder mounted successfully" >> ~/backup.log
		else
			mount_success=0
			# echo "NFS backup folder not mounted" >> ~/backup.log
		fi
	else
		mount_success=0
		# echo "NFS backup folder not mounted" >> ~/backup.log
	fi
else
	mount_success=1
	# echo "NFS backup folder mounted successfully" >> ~/backup.log
fi
}

function write_log {
t_str=$1

my_date=$(date '+%d %b %Y %H:%M:%S')
t_out_str="${my_date}  ${t_str}"

if [[ ! -f $log_file_local ]]; then
	echo $t_out_str > $log_file_local
else
	echo $t_out_str >> $log_file_local
fi
}

function compactLog() {
local max_empty_log_lines=40

if [[ ! -f $log_file_local ]]; then
	return
fi

empty_log_lines=$(cat $log_file_local | grep -i "mounted successfully" | wc -l)
if [[ $empty_log_lines -ge $max_empty_log_lines ]]; then
	last_lines_none=$(cat $log_file_local | tail -8 | grep -iv "mounted successfully")
	if [[ -z $last_lines_none ]]; then
		cat $log_file_local | grep -iv "mounted successfully" > $log_file_tmp
		cat $log_file_local | tail -8 >> $log_file_tmp
		mv $log_file_tmp $log_file_local
	else
		cat $log_file_local | grep -iv "mounted successfully" > $log_file_tmp
		mv $log_file_tmp $log_file_local
	fi
fi
}

function checkFilesEqual {
if [[ -z $1 ]]; then
	return 1
else
	t_file1=$1
fi

if [[ -z $2 ]]; then
	return 1
else
	t_file2=$2
fi

if [[ -f $t_file1 ]]; then
	t_size1=$(ls -l $t_file1 | awk '{print $5}')
else
	t_size1=0
fi

if [[ -f $t_file1 ]]; then
	t_size2=$(ls -l $t_file2 | awk '{print $5}')
else
	t_size2=0
fi

if [[ $t_size1 -eq $t_size2 ]]; then
	return 0
else
	return 1
fi
}

function checkFilesEqualMD5 {
if [[ -z $1 ]]; then
	return 1
else
	t_file1=$1
fi

if [[ -z $2 ]]; then
	return 1
else
	t_file2=$2
fi

if [[ -f $t_file1 ]]; then
	t_md5_1=$(md5sum $t_file1 | awk '{print $1}')
else
	t_md5_1="md5_1"
fi

if [[ -f $t_file1 ]]; then
	t_md5_2=$(md5sum $t_file2 | awk '{print $1}')
else
	t_md5_2="md5_2"
fi

if [[ $t_md5_1 == $t_md5_2 ]]; then
	return 0
else
	return 1
fi
}

compactLog
mountNFSBackup

if [[ $mount_success -eq 1 ]]; then
	write_log "Updater started. NFS folder mounted successfully"
	
	if [[ ! -d $script_path_local ]]; then
		mkdir $script_path_local
		# if [[ $mount_success -eq 1 ]]; then
			# cp $script_full_path_share $script_full_path_local
			# cp $script_launcher_full_path_share $script_launcher_full_path_local
		# fi
	fi

	script_size=$(ls -l $script_full_path_local | awk '{print $5}')
	if [[ $script_size -lt 10000 ]]; then
		rm $script_full_path_local
	fi

	script_launcher_size=$(ls -l $script_launcher_full_path_local | awk '{print $5}')
	if [[ $script_launcher_size -lt 3000 ]]; then
		rm $script_launcher_full_path_local
	fi

	if [[ ! -f $script_full_path_local ]]; then
		checkFilesEqual $script_full_path_share $script_full_path_local
		until [[ $? -eq 0 ]]; do
			cp $script_full_path_share $script_full_path_local
			checkFilesEqual $script_full_path_share $script_full_path_local
		done
	fi

	if [[ ! -f $script_launcher_full_path_local ]]; then
		checkFilesEqual $script_launcher_full_path_share $script_launcher_full_path_local
		until [[ $? -eq 0 ]]; do
			cp $script_launcher_full_path_share $script_launcher_full_path_local
			checkFilesEqual $script_launcher_full_path_share $script_launcher_full_path_local
		done
	fi

	share_script_change_time=$(stat -c %Y $script_full_path_share)
	local_script_change_time=$(stat -c %Y $script_full_path_local)
	
	if [[ $share_script_change_time -gt $local_script_change_time ]]; then
		checkFilesEqual $script_full_path_share $script_full_path_local
		until [[ $? -eq 0 ]]; do
			cp $script_full_path_share $script_full_path_local
			checkFilesEqual $script_full_path_share $script_full_path_local
		done
		write_log "Script $script_name_local updated from share script folder"
	fi
	
	share_script_launcher_change_time=$(stat -c %Y $script_launcher_full_path_share)
	local_script_launcher_change_time=$(stat -c %Y $script_launcher_full_path_local)
		
	if [[ $share_script_launcher_change_time -gt $local_script_launcher_change_time ]]; then
		checkFilesEqual $script_launcher_full_path_share $script_launcher_full_path_local
		until [[ $? -eq 0 ]]; do
			cp $script_launcher_full_path_share $script_launcher_full_path_local
			checkFilesEqual $script_launcher_full_path_share $script_launcher_full_path_local
		done
		write_log "Script $script_launcher_name_local updated from share script folder"	
	fi				
else
	write_log "Updater started. NFS folder not mounted"

	script_size=$(ls -l $script_full_path_local | awk '{print $5}')
	if [[ $script_size -lt 10000 ]]; then
		rm $script_full_path_local
	fi

	script_launcher_size=$(ls -l $script_launcher_full_path_local | awk '{print $5}')
	if [[ $script_launcher_size -lt 3000 ]]; then
		rm $script_launcher_full_path_local
	fi	
fi

# eval "$exec_line"