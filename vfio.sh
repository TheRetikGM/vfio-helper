#!/bin/bash
# Quick and dirty script for loading VFIO drivers on the fly
# - IOMMU must be enabled and working: https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Setting_up_IOMMU
# - Currently only works for some NVIDIA gpu setups
# - Tested on: Fedora Linux 40 (KDE Plasma)
#
# USAGE (as root):
# ./vfio.sh                List GPU pci ids
# ./vfio.sh bind           Load vfio drivers
# ./vfio.sh unbind         Unload vfio drivers

gpu=`lspci | grep -ie "vga.*nvidia" | awk '{print $1}'`
aud=`lspci | grep -ie "audio.*nvidia" | awk '{print $1}'`
nvidia_modules=(nvidia_drm nvidia_modeset nvidia_uvm nvidia)

function bind_vfio_pci {
	local pci="$1"
	local pci_vd="$(cat /sys/bus/pci/devices/$pci/vendor) $(cat /sys/bus/pci/devices/$pci/device)"
	echo "VFIO: Binding PCI device $pci with id '$pci_vd'"
	echo "$pci_vd" > /sys/bus/pci/drivers/vfio-pci/new_id
	echo "$pci" > /sys/bus/pci/devices/$pci/driver/unbind
	echo "$pci" > /sys/bus/pci/drivers/vfio-pci/bind
	echo "$pci_vd" > /sys/bus/pci/drivers/vfio-pci/remove_id
}

function bind_vfio {
	if ! bind_vfio_pci $gpu || ! bind_vfio_pci $aud; then
		exit 1
	fi
}

function unbind_vfio {
	echo "Removing NVIDIA GPU from PCI bus"
	echo 1 > /sys/bus/pci/devices/$gpu/remove
	echo 1 > /sys/bus/pci/devices/$aud/remove
	echo "Rescanning PCI devices"
	echo 1 > /sys/bus/pci/rescan
}

function unload_nvidia {
	if ps aux | grep nvidia-powerd | grep -vq grep; then
		echo "Stopping nvidia-powerd service"
		systemctl stop nvidia-powerd.service
	fi

	# Check if anything else is using the card
	local pids=`lsof /dev/nvidia* 2> /dev/null | grep -v PID | awk '{print $2}' | uniq | xargs`
	if [ "$pids" != "" ]; then
		echo "NVIDIA GPU is in use by: $pids" >&2
		exit 1
	fi

	echo "Unloading nvidia modules"
	for module in ${nvidia_modules[@]}; do
		modprobe -r $module
	done
}

function systemctl-exists {
  [ $(systemctl list-unit-files "${1}*" | wc -l) -gt 3 ]
}

function load_nvidia {
	# PCI rescan may load the nouveau module
	if lsmod | grep -wq nouveau; then
		modprobe -r nouveau
	fi

	echo "Loading nvidia modules"
	for module in `echo ${nvidia_modules[@]} | awk '{ for(i=NF;i>0;i--) printf "%s ",$i; }'`; do
		modprobe $module
	done
	
	# Start the nvidia-powerd service if its available
	if systemctl-exists nvidia-powerd; then
		echo "Starting nvidia-powerd service"
		systemctl start nvidia-powerd.service
	fi
}

function load_vfio {
	if ! lsmod | grep -wq vfio_pci; then
		echo "Loading vfio_pci module"
		modprobe vfio_pci
	fi
}

function unload_vfio {
	echo "Unloading vfio_pci module"
	modprobe -r vfio_pci
}

if [ "$1" = "bind" ]; then
	if ! unload_nvidia || ! load_vfio || ! bind_vfio; then
		exit 1
	fi
	
	echo ""
	echo "Binding complete! Check driver: \`lspci -ks `echo $gpu | cut -d'.' -f1`\`"
	exit 0
fi

if [ "$1" = "unbind" ]; then
	if ! unbind_vfio || ! unload_vfio || ! load_nvidia; then
		exit 1
	fi

	echo ""
	echo "Unbinding complete! Check driver: \`lspci -ks `echo $gpu | cut -d'.' -f1`\`"
	exit 0
fi

echo "GPU:       $gpu"
echo "GPU Audio: $aud"

