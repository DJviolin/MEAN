#!/bin/bash

# set -e making the commands if they were like &&
set -e

read -e -p "Enter the path to the install dir (or hit enter for default path): " -i "$HOME/server-mean" INSTALL_DIR
echo $INSTALL_DIR

echo -e "\nCreating folder structure:"
mkdir -p $INSTALL_DIR/mongodb/data/db $INSTALL_DIR/dbbackup $INSTALL_DIR/repo $INSTALL_DIR/www
echo -e "\
  $INSTALL_DIR/mongodb/data/db\n\
  $INSTALL_DIR/dbbackup\n\
  $INSTALL_DIR/repo\n\
  $INSTALL_DIR/www\n\
Done!"

if test "$(ls -A "$INSTALL_DIR/repo")"; then
  echo -e "\n\"$INSTALL_DIR/repo\" directory is not empty!\nYou have to remove everything from here to continue!\nRemove \"$INSTALL_DIR/repo\" directory (y/n)?"
  read answer
  if echo "$answer" | grep -iq "^y" ;then
    rm -rf $INSTALL_DIR/repo/
    echo -e "\"$INSTALL_DIR/repo\" is removed, continue installation...";
    mkdir -p $INSTALL_DIR/repo
    echo -e "\nCloning git repo into \"$INSTALL_DIR/repo\":"
    cd $INSTALL_DIR/repo
    git clone https://github.com/DJviolin/mean.git $INSTALL_DIR/repo
    echo -e "\nShowing working directory..."
    ls -al $INSTALL_DIR/repo
  else
    echo -e "\nScript aborted to run\nExiting..."; exit 1;
  fi
else
  echo -e "\nCloning git repo into \"$INSTALL_DIR/repo\":"
  cd $INSTALL_DIR/repo
  git clone https://github.com/DJviolin/mean.git $INSTALL_DIR/repo
  echo -e "Showing working directory..."
  ls -al $INSTALL_DIR/repo
fi

echo -e "\nCreating additional files for the stack:"

# bash variables in Here-Doc, don't use 'EOF'
# http://stackoverflow.com/questions/4937792/using-variables-inside-a-bash-heredoc
# http://stackoverflow.com/questions/17578073/ssh-and-environment-variables-remote-and-local

echo -e "\nCreating: $INSTALL_DIR/repo/docker-compose.yml\n"
cat <<EOF > $INSTALL_DIR/repo/docker-compose.yml
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
  container_name: mean_base_exited
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
  container_name: mean_node_exited
  links:
    - base
app:
  build: ./app
  container_name: mean_app
  links:
    - base
  ports:
    - "3000:3000"
  volumes:
    - $INSTALL_DIR/www:/usr/src/app:rw
EOF
cat $INSTALL_DIR/repo/docker-compose.yml

echo -e "\nCreating: $INSTALL_DIR/repo/mean.service\n"
cat <<EOF > $INSTALL_DIR/repo/mean.service
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
ExecStartPre=-/opt/bin/docker-compose --file $INSTALL_DIR/repo/docker-compose.yml kill
ExecStartPre=-/opt/bin/docker-compose --file $INSTALL_DIR/repo/docker-compose.yml rm --force
ExecStart=/opt/bin/docker-compose --file $INSTALL_DIR/repo/docker-compose.yml up --force-recreate
ExecStartPost=/usr/bin/etcdctl set /mean Running
ExecStop=/opt/bin/docker-compose --file $INSTALL_DIR/repo/docker-compose.yml stop
ExecStopPost=/usr/bin/etcdctl rm /mean
ExecStopPost=-/usr/bin/docker cp mean_mongodb:/data $INSTALL_DIR/dbbackup
ExecStopPost=-/bin/bash -c 'tar -zcvf $INSTALL_DIR/dbbackup/dbbackup_\$\$(date +%%Y-%%m-%%d_%%H-%%M-%%S)_ExecStopPost.tar.gz $INSTALL_DIR/dbbackup/mongodb --remove-files'
Restart=always
#RestartSec=30s

[X-Fleet]
Conflicts=mean.service
EOF
cat $INSTALL_DIR/repo/mean.service

cd $HOME

echo -e "\n
MEAN stack has successfully built!\n\n\
Run docker-compose with:\n\
  $ docker-compose --file $INSTALL_DIR/repo/docker-compose.yml build\n\
Run the systemd service with:\n\
  $ cd $INSTALL_DIR/repo && chmod +x service-start.sh && ./service-start.sh\n\
Stop the systemd service with:\n\
  $ cd $INSTALL_DIR/repo && chmod +x service-stop.sh && ./service-stop.sh"
echo -e "\nAll done! Exiting..."
