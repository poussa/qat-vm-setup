# Intro

Quick info how to run haproxy+openssl+QAT on VM as a non-root.

These instructions has been tested on Centos 7 & 8 and Debian 9.

# Build QAT driver for host

```bash
mkdir QAT
cd QAT
curl -O https://01.org/sites/default/files/downloads//qat1.7.l.4.7.0-00006.tar.gz
tar xzf qat1.7.l.4.7.0-00006.tar.gz
export ICP_ROOT=$PWD
./configure --enable-icp-sriov=host
make
sudo make install
```

TODO: Test if this step is really needed. The kernel upstream driver may be enough.

# Enable IOMMU on host 

The kernel must have the `intel_iommu=on` kernel cmdline parameter. Check you distro how to do that.

```bash
[spoussa@s2600wf ~]$ cat /proc/cmdline
BOOT_IMAGE=/vmlinuz-5.1.15-1.el7.elrepo.x86_64 root=/dev/mapper/centos-root ro crashkernel=auto rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet intel_iommu=on
```

# Make QAT SRIOV devices available for VMs via vfio-pci

There are many ways to do this but here is one example using the DPDK tool.

```bash
dpdk-devbind -b vfio-pci $(for i in 37c9; do lspci -D -d 8086:$i; done|awk '{print $1}')
```

Alternatively, you can run the vfio-setup.sh script.

```bash
./vfio-setup.sh
```

NOTE: This needs to be done after every host reboot.

# Build QAT diriver for VM (guest)

Same as in host case but with the guest option.


```bash
mkdir QAT
cd QAT
curl -O https://01.org/sites/default/files/downloads/qat1.7.l.4.7.0-00006.tar.gz
export ICP_ROOT=$PWD
./configure --enable-icp-sriov=guest
make
sudo make install
```

# Build openssl (v1.1.1)

```bash
cd $HOME
git clone https://github.com/openssl/openssl.git
cd openssl
git checkout tags/OpenSSL_1_1_1d -b openssl-1.1.1
./config --prefix=/usr/local/ssl
make
sudo make install
```


# Build QAT engine

```bash
cd $HOME
export QAT_ENGINE_VERSION="v0.5.42"
export ICP_ROOT=$HOME/QAT
export LIBRPATH=/usr/local/ssl
export LD_LIBRARY_PATH=/usr/local/ssl/lib
export OPENSSL_ENGINES=/usr/local/ssl/lib/engines-1.1
export PERL5LIB=$PERL5LIB:$PWD/openssl

```

```bash
cd $HOME
git clone https://github.com/intel/QAT_Engine.git
cd QAT_Engine
git checkout $QAT_ENGINE_VERSION
./autogen.sh
./configure \
--with-qat_dir=$HOME/QAT \
--with-openssl_dir=$HOME/openssl \
--with-openssl_install_dir=/usr/local/ssl \
--enable-upstream_driver \
--enable-usdm \
--enable-qat_skip_err_files_build 
make
sudo make install
```

# Create QAT config file

The config file is `/etc/c6xxvf_dev0.conf` or similar

```bash
[GENERAL]
ServicesEnabled = cy
ConfigVersion = 2
CyNumConcurrentSymRequests = 512
CyNumConcurrentAsymRequests = 64

statsGeneral = 1
statsDh = 1
statsDrbg = 1
statsDsa = 1
statsEcc = 1
statsKeyGen = 1
statsDc = 1
statsLn = 1
statsPrime = 1
statsRsa = 1
statsSym = 1

[KERNEL]
NumberCyInstances = 0
NumberDcInstances = 0

[SHIM]
NumberCyInstances = 1
NumberDcInstances = 0
NumProcesses = 1
LimitDevAccess = 0
Cy0Name = "SHIM0"
Cy0IsPolled = 1
Cy0CoreAffinity = 0
```

Restart the QAT service to use the new configuration.

```bash
sudo service qat_service restart
```

Make sure the new configuration is sucessfully loaded. You should see something like this in the `dmesg`.

```bash
[24111.663537] QAT: Stopping all acceleration devices.
[24111.665487] c6xxvf 0000:08:00.0: Starting acceleration device qat_dev0.
```

# Create new group, add user and change permissions

Change the `TARGET` as needed.

```bash
TARGET=$USER
GRP=qat

sudo usermod -G $GRP $TARGET

sudo chgrp $GRP /dev/qat_*
sudo chgrp $GRP /dev/usdm_drv
sudo chgrp $GRP /dev/uio*

echo "@qat - memlock 4096" | sudo tee -a /etc/security/limits.conf

echo "@qat - nofile 8192" | sudo tee -a /etc/security/limits.conf
```

# Generate certs

```bash
FQDN=localhost
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout haproxy.key -out haproxy.crt -subj "/C=FI/O=Intel SSP/CN=${FQDN}"
cat haproxy.crt haproxy.key > haproxy.pem
```

# Run HA proxy

```bash
/usr/sbin/haproxy -f haproxy.conf
```

# Run web server

```bash
node server.js
```

# Do HTTP Query

```bash
curl --cacert haproxy.crt https://localhost:8443
``` 