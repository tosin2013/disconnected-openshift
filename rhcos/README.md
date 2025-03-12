# Red Hat CoreOS

> Cloud platform guidance is omitted - if you're doing disconnected deployments in the cloud and can't use the build-in AMIs/VMIs you have different kinds of problems I don't want any part of.

One of the major things you'll need to deploy OpenShift in a disconnected environment are the RHCOS boot/install assets.

Depending on what platform, and what installation method you choose, you may need different things:

- IPI and UPI will need different platform images, eg IMGs, OVAs, QCOW2s, etc.
- ACM IPI via Hive will need the same platform images, eg IMGs, OVAs, QCOW2s, etc.
- Assisted Installer via ACM/MCE will need Live ISO images and components
- Agent Based Installer pulls the Live ISO from a container

Pretty much all the resources can be found here: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/

> *For x86_64 that is - for other architectures you can find paths a few folders up*

Select what version you want and mirror as needed.  It's best to keep the same RHCOS images for the same OCP releases - you may find compatibility between adjacent versions, however it is not supported and prone to providing breaking changes, eg the transition from 4.11 to 4.12 that was based on a RHEL/RHCOS 8 to 9 transition.

As a rule of thumb, you can use the `4.xx/latest` path for the RHCOS assets safely.  There are fewer Z-stream RHCOS releases since there are fewer things to update, though you may see releases to patch bugs/vulnerabilities in the underlying RHCOS.

Assuming you're preparing for an x86_64 OpenShift 4.18 deployment, these are the assets you'll need for various deployments/infrastructure providers:

## Agent Based Installer

No other RHCOS media is needed!  When you execute the `openshift-install agent` command the RHCOS ISO it generates is sourced from a container image - so long as you have your mirror registry set up, then there are no further steps required.

## Hosted Assisted Installer

*Assisted Installer cloud service?!?! In a disconnected environment?!?!  wot in tarnation*

Well, if all you have is an allow-list/outbound proxy, then it'll work - but you still don't need to mirror any other RHCOS assets for the Assisted Installer, it'll generate the only ISO you'll need to boot systems with.

## IPI/UPI, ACM IPI via Hive

- **Bare Metal, default**: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-metal.x86_64.raw.gz
- **Bare Metal, 4K Page Sizes**: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-metal4k.x86_64.raw.gz
- **Bare Metal Bootstrap for IPI/UPI**: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-qemu.x86_64.qcow2.gz
- **Libvirt, QCOW2**: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-qemu.x86_64.qcow2.gz
- **OpenStack, QCOW2**: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-openstack.x86_64.qcow2.gz
- **Nutanix, QCOW2**: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-nutanix.x86_64.qcow2
- **vSphere, OVA**: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-vmware.x86_64.ova
- **PXE Booting**:
  - **InitRAMFS:** https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-installer-initramfs.x86_64.img
  - **Kernel:** https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-installer-kernel-x86_64
  - **Root File System:** https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-installer-rootfs.x86_64.img

Once you have the needed asset for your platform downloaded, you'll provide it via an HTTP server and point to it with some configuration in the `install-config.yaml` file.

## Assisted Service via ACM/MCE

When using the Host Inventory mechanism in ACM, the underlying Assisted Service will need some RHCOS images.  Unfortunately, it can't simply take outbound proxy configuration so you have to manually mirror/serve the assets for the Assisted Image Service to then download and use.

You can get around this limitation by either manually mirroring the assets and serving them with an existing HTTP server in your environment, or use the HTTP Mirror application in the `extras` folder.  This application can download sources, and then serve them via HTTP.  In fact this application can download/serve any of the assets you need available via HTTP.

- **RHCOS Live ISO**: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-live.x86_64.iso
- **RHCOS Live ISO Root FS**: https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/4.17/latest/rhcos-live-rootfs.x86_64.img

Those two will be used to bake ISOs by the Assisted Service and extract into components for iPXE booting.

## Bonus: HTTP Servers

In order to use the RHCOS you need to have them hosted on an HTTP server.  You can do so easily with some assets provided in this repo.

If you want to just spin up a quick NGINX container on a Linux host, check out [../extras/nginx-container/](../extras/nginx-container/).

If you have a server or OpenShift cluster sitting inbetween the DMZ and a higher class network, you can use the [HTTP Mirror application](../extras/http-mirror/) to automatically download the assets and serve them.