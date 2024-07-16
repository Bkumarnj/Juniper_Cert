qm create 102 --name=BKNJ-LabGFW-vSRX01 --memory=4092 --sockets=1 --cores=2 --balloon=0 \
  --machine pc-q35-8.0 --serial0=socket --scsihw=virtio-scsi-pci --cpu=host --ostype=l26 \
  --net0=virtio,bridge=vmbr1 --net1=virtio,bridge=vmbr1 --net2=virtio,bridge=vmbr2 --net3=virtio,bridge=vmbr3

qm set 102 -args '-machine smbios-entry-point-type=32'

qm importdisk 102 vSRX-23.2R2.21.qcow2 local-lvm

qm set 102 --scsi0 local-lvm:vm-102-disk-0

qm set 102 --boot order=scsi0
