#!/bin/bash

# set -e making the commands if they were like &&
set -e

read -e -p "Enter the path to the install dir (or hit enter for default path): " -i "$HOME/server" INSTALL_DIR
echo $INSTALL_DIR

echo -e "\nCreating folder structure:"
mkdir -p $INSTALL_DIR/mongodb/data/db $INSTALL_DIR/dbbackup $INSTALL_DIR/mean $INSTALL_DIR/www
echo -e "\
  $INSTALL_DIR/mongodb/data/db\n\
  $INSTALL_DIR/dbbackup\n\
  $INSTALL_DIR/mean\n\
  $INSTALL_DIR/www\n\
Done!"

if test "$(ls -A "$INSTALL_DIR/mean")"; then
  echo -e "\n\"$INSTALL_DIR/mean\" directory is not empty!\nYou have to remove everything from here to continue!\nRemove \"$INSTALL_DIR/mean\" directory (y/n)?"
  read answer
  if echo "$answer" | grep -iq "^y" ;then
    rm -rf $INSTALL_DIR/mean/
    echo -e "\"$INSTALL_DIR/mean\" is removed, continue installation...";
    mkdir -p $INSTALL_DIR/mean
    echo -e "\nCloning git repo into \"$INSTALL_DIR/mean\":"
    cd $INSTALL_DIR/mean
    git clone https://github.com/DJviolin/mean.git $INSTALL_DIR/mean
    echo -e "\nShowing working directory..."
    ls -al $INSTALL_DIR/mean
  else
    echo -e "\nScript aborted to run\nExiting..."; exit 1;
  fi
else
  echo -e "\nCloning git repo into \"$INSTALL_DIR/mean\":"
  cd $INSTALL_DIR/mean
  git clone https://github.com/DJviolin/mean.git $INSTALL_DIR/mean
  echo -e "Showing working directory..."
  ls -al $INSTALL_DIR/mean
fi

echo -e "\nCreating additional files for the stack:"

# bash variables in Here-Doc, don't use 'EOF'
# http://stackoverflow.com/questions/4937792/using-variables-inside-a-bash-heredoc
# http://stackoverflow.com/questions/17578073/ssh-and-environment-variables-remote-and-local

echo -e "\nCreating: $INSTALL_DIR/mean/docker-compose.yml\n"
cat <<EOF > $INSTALL_DIR/mean/docker-compose.yml
cadvisor:
  image: google/cadvisor:latest
  container_name: mean_cadvisor
  ports:
    - "8080:8080"
  volumes:
    - "/:/rootfs:ro"
    - "/var/run:/var/run:rw"
    - "/sys:/sys:ro"
    - "/var/lib/docker/:/var/lib/docker:ro"
base:
  build: ./base
  container_name: mean_base
  volumes:
  - $INSTALL_DIR/www/:/var/www/:rw
mongodb:
  build: ./mongodb
  container_name: mean_mongodb
  links:
    - base
  ports:
    - "27017:27017"
  volumes:
    - $INSTALL_DIR/mongodb/data/db:/data/db
node:
  build: ./node
  container_name: mean_node
  links:
    - base
  ports:
    - "3000:3000"
  volumes_from:
    - base
    - mongodb
EOF
cat $INSTALL_DIR/mean/docker-compose.yml

echo -e "\nCreating: $INSTALL_DIR/mean/mean.service\n"
cat <<EOF > $INSTALL_DIR/mean/mean.service
[Unit]
Description=mean
After=etcd.service
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
#KillMode=none
ExecStartPre=-/usr/bin/docker cp mean_mongodb:/data $INSTALL_DIR/dbbackup
ExecStartPre=-/bin/bash -c '/usr/bin/tar -zcvf $INSTALL_DIR/dbbackup/dbbackup_\$\$(date +%%Y-%%m-%%d_%%H-%%M-%%S)_ExecStartPre.tar.gz $INSTALL_DIR/dbbackup/mongodb --remove-files'
ExecStartPre=-/opt/bin/docker-compose --file $INSTALL_DIR/mean/docker-compose.yml kill
ExecStartPre=-/opt/bin/docker-compose --file $INSTALL_DIR/mean/docker-compose.yml rm --force
ExecStart=/opt/bin/docker-compose --file $INSTALL_DIR/mean/docker-compose.yml up --force-recreate
ExecStartPost=/usr/bin/etcdctl set /mean Running
ExecStop=/opt/bin/docker-compose --file $INSTALL_DIR/mean/docker-compose.yml stop
ExecStopPost=/usr/bin/etcdctl rm /mean
ExecStopPost=-/usr/bin/docker cp mean_mongodb:/data $INSTALL_DIR/dbbackup
ExecStopPost=-/bin/bash -c 'tar -zcvf $INSTALL_DIR/dbbackup/dbbackup_\$\$(date +%%Y-%%m-%%d_%%H-%%M-%%S)_ExecStopPost.tar.gz $INSTALL_DIR/dbbackup/mongodb --remove-files'
Restart=always
#RestartSec=30s

[X-Fleet]
Conflicts=mean.service
EOF
cat $INSTALL_DIR/mean/mean.service

cd $HOME

echo -e "\n
MEAN stack has successfully built!\n\n\
Run docker-compose with:\n\
  $ docker-compose --file $INSTALL_DIR/mean/docker-compose.yml build\n\
Run the systemd service with:\n\
  $ cd $INSTALL_DIR/mean && chmod +x service-start.sh && ./service-start.sh\n\
Stop the systemd service with:\n\
  $ cd $INSTALL_DIR/mean && chmod +x service-stop.sh && ./service-stop.sh"
echo -e "\nAll done! Exiting..."
