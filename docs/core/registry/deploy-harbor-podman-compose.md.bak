# Deploy Harbor with Podman Compose

In case you need a quick little container registry, Harbor is a great option.

## Prerequisites

- A Linux VM or something to run Harbor - gonna use RHEL 9 for this one
- Enough disk space to mirror a *WHOLE BUNCHA IMAGES*
- An IP address
- A DNS record pointing to that IP address

## Install System Packages

```bash
# Install some packages
dnf install -y podman cockpit-podman python3-pip git

# Install Podman Compose
python3 -m pip install podman-compose

# May need to add /usr/local/bin to your user's PATH env var

# Test
podman compose

# Sneeky hax
ln -s /usr/bin/podman /usr/bin/docker
```

You may have noticed I snuck in that `cockpit-podman` package - if you run `systemctl enable --now cockpit.socket` then you can access the Cockpit web interface and see the Harbor containers that are about to be deployed...

## Download Harbor

What's really nice about Harbor is they have this handy offline installer - grab the latest one from here: https://github.com/goharbor/harbor/releases

```bash
# Go somewhere cozy
cd /opt

# Make a directory for harbor things
mkdir harbor-data

# Download the Installer
wget https://github.com/goharbor/harbor/releases/download/v2.12.2/harbor-offline-installer-v2.12.2.tgz

# Extract the Installer
tar zxvf harbor-offline-installer-v2.12.2.tgz

# Enter the extracted harbor directory
cd harbor
```

## Configure HTTPS

You can use either a self-signed SSL certificate for Harbor, or one from your internal PKI - even an external one if you feel like paying for it or if it's public on the Internet for things like Let's Encrypt.

TLS is outside the scope of this doc, you can read more and find steps on generating a self-signed cert here: https://goharbor.io/docs/1.10/install-config/configure-https/

You could also use this awesome thing to roll your own PKI: https://github.com/kenmoini/pika-pki

## Configure Harbor

Before we deploy things, we need to set up some configuration.

You can find the default `harbor.yml` configuration options in `harbor.yml.tmpl` in the folder that was extracted.

Additional configuration details and options can be found here: https://goharbor.io/docs/1.10/install-config/configure-yml-file/

The key configuration parameters to specify are:

```yaml
# The IP address or hostname to access admin UI and registry service.
# DO NOT use localhost or 127.0.0.1, because Harbor needs to be accessed by external clients.
hostname: disconn-harbor.d70.kemo.labs

# http related config
http:
  # port for http, default is 80. If https enabled, this port will redirect to https port
  port: 80

# https related config
https:
  # https port for harbor, default is 443
  port: 443
  # The path of cert and key files for nginx
  certificate: /etc/docker/certs.d/disconn-harbor.d70.kemo.labs:443/disconn-harbor.d70.kemo.labs.cert
  private_key: /etc/docker/certs.d/disconn-harbor.d70.kemo.labs:443/disconn-harbor.d70.kemo.labs.key

# Set this to that folder we created earlier
data_volume: /opt/harbor-data

# In case this Harbor deployment is behind an Outbound Proxy, configure it similarly
proxy:
  http_proxy: http://proxy.kemo.labs:3129
  https_proxy: http://proxy.kemo.labs:3129
  no_proxy: localhost,.kemo.labs,.kemo.network,10.128.0.0/14,127.0.0.1,172.30.0.0/16,192.168.0.0/16
  components:
    - core
    - jobservice
    - trivy
```

There are other standard things such as the `harbor_admin_password`, db stuff, etc - but that's not in the scope of "disconnected things".

## Run the Installer

With the `harbor.yml` configuration set, just run the installer to get things started

```bash
# Lett'errip
./install.sh
```

Notice that it errors out due to how it checks for the version of Docker - which is not the same as the version of Podman!

To get around this, just modify the `common.sh` file, comment out the `exit 1` lines in the `check_docker` function.

**Run it again** - and you should see it fail with some weird unexplainable error!  This is due to SELinux lolololo.  Execute `setenforce 0` - Harbor doesn't like SELinux.

Run `./install.sh` **once again** - and it'll still end up failing.  This is due to how Harbor handles logging and the fact that Podman does not support syslog endpoints - edit the `docker-compose.yml` file and remove the `logging` stanzas from all the container definitions that have it.

***NOW*** - you can run the `./install.sh` script again, which should succeed and give you access to it in your browser.  *You could even see how healthy they are at a glance in the Cockpit dashboard.*

![Harbor - with Podman!](../static/harbor-running-in-cockpit.jpg)