# Credit to Eric Adams (eric.adams@intel.com)
# https://github.com/kata-containers/documentation/blob/master/use-cases/using-Intel-QAT-and-kata.md
#


sudo modprobe vfio-pci
QAT_PCI_BUS_PF_NUMBERS=$((lspci -d :435 && lspci -d :37c8 && lspci -d :19e2 && lspci -d :6f54) | cut -d ' ' -f 1)
QAT_PCI_BUS_PF_1=$(echo $QAT_PCI_BUS_PF_NUMBERS | cut -d ' ' -f 1)
echo 16 | sudo tee /sys/bus/pci/devices/0000:$QAT_PCI_BUS_PF_1/sriov_numvfs
QAT_PCI_ID_VF=$(cat /sys/bus/pci/devices/0000:${QAT_PCI_BUS_PF_1}/virtfn0/uevent | grep PCI_ID)
QAT_VENDOR_AND_ID_VF=$(echo ${QAT_PCI_ID_VF/PCI_ID=} | sed 's/:/ /')
echo $QAT_VENDOR_AND_ID_VF | sudo tee --append /sys/bus/pci/drivers/vfio-pci/new_id

for f in /sys/bus/pci/devices/0000:$QAT_PCI_BUS_PF_1/virtfn*
  do QAT_PCI_BUS_VF=$(basename $(readlink $f))
   echo $QAT_PCI_BUS_VF | sudo tee --append /sys/bus/pci/drivers/c6xxvf/unbind
   echo $QAT_PCI_BUS_VF | sudo tee --append /sys/bus/pci/drivers/vfio-pci/bind
  done
