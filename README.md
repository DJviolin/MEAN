# MEAN stack built on Docker

Work in progress! NOT FOR PRODUCTION!

## Prerequisites

1. Linux
2. 1GB Ram
3. 20GB disk size (preferably fixed size in virtual machines)
4. Git
5. Docker Client
6. Systemd
7. Docker-compose
8. Place your personal SSH public key in `~/.ssh/authorized_keys` file on your HOST

## Installation

Basic install script provided. Run only `./install-mean.sh` and follow the instructions in the script! You doesn't even need to clone this repo (the script will do it anyway), just only download this file to your host and run it if you wish!

```
$ curl -L https://raw.github.com/DJviolin/mean/master/install-mean.sh > $HOME/install-mean.sh
$ chmod +x $HOME/install-mean.sh
$ cd $HOME
$ ./install-mean.sh
$ rm -rf $HOME/install-mean.sh
```

The script will create the `docker-compose.yml` and `mean.service` files inside the cloned repo, which are needed for docker-compose and systemd.

## Usage

Run docker-compose with:

```
$ docker-compose --file $HOME/server/mean/docker-compose.yml build
```

Start the Systemd service:

```
$ cd $HOME/server/mean
$ chmod +x service-start.sh
$ ./service-start.sh
```

Stop the systemd service:

```
$ cd $HOME/server/mean
$ chmod +x service-stop.sh
$ ./service-stop.sh
```

## Docker-compose installation on CoreOS

If you happens to be a `CoreOS` user and you want to install `docker-compose`, you can install it with superuser access:

```
$ sudo su
$ mkdir -p /opt/bin
$ curl -L https://github.com/docker/compose/releases/download/1.5.2/docker-compose-`uname -s`-`uname -m` > /opt/bin/docker-compose
$ chmod +x /opt/bin/docker-compose
$ exit
```

Or without any superuser access, from the nightly release channel:

```
# Removing symlink from /usr/share/skel/.bashrc in cave man style
$ cp $HOME/.bashrc $HOME/.bashrc.new
$ rm $HOME/.bashrc
$ mv $HOME/.bashrc.new $HOME/.bashrc
$ chmod a+x $HOME/.bashrc
# Echoing docker-compose PATH variable
$ echo -e 'export PATH="$PATH:$HOME/bin"' >> $HOME/.bashrc
$ curl -L https://dl.bintray.com/docker-compose/master/docker-compose-`uname -s`-`uname -m` > $HOME/bin/docker-compose
$ chmod +x $HOME/bin/docker-compose
# Reloading .bashrc without opening a new bash instance
$ source $HOME/.bashrc
```

## Notes

Future work: https://github.com/jwilder/nginx-proxy

