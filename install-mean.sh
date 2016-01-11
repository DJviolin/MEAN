#!/bin/bash

# set -e making the commands if they were like &&
set -e

read -e -p "Enter the path to the install dir (or hit enter for default path): " -i "$HOME/server-mean" INSTALL_DIR
echo $INSTALL_DIR
DB_DIR=$INSTALL_DIR/mongodb
DBBAK_DIR=$INSTALL_DIR/dbbackup
REPO_DIR=$INSTALL_DIR/repo
WWW_DIR=$INSTALL_DIR/www

echo -e "\nCreating folder structure:"
mkdir -p $DB_DIR/data/db $DBBAK_DIR $REPO_DIR $WWW_DIR
echo -e "\
  $DB_DIR/data/db\n\
  $DBBAK_DIR\n\
  $REPO_DIR\n\
  $WWW_DIR\n\
Done!"

if test "$(ls -A "$REPO_DIR")"; then
  echo -e "\n\"$REPO_DIR\" directory is not empty!\nYou have to remove everything from here to continue!\nRemove \"$REPO_DIR\" directory (y/n)?"
  read answer
  if echo "$answer" | grep -iq "^y" ;then
    rm -rf $REPO_DIR/
    echo -e "\"$REPO_DIR\" is removed, continue installation...";
    mkdir -p $REPO_DIR
    echo -e "\nCloning git repo into \"$REPO_DIR\":"
    cd $REPO_DIR
    git clone https://github.com/DJviolin/mean.git $REPO_DIR
    echo -e "\nShowing working directory..."
    ls -al $REPO_DIR
  else
    echo -e "\nScript aborted to run\nExiting..."; exit 1;
  fi
else
  echo -e "\nCloning git repo into \"$REPO_DIR\":"
  cd $REPO_DIR
  git clone https://github.com/DJviolin/mean.git $REPO_DIR
  echo -e "Showing working directory..."
  ls -al $REPO_DIR
fi

echo -e "\nCreating additional files for the stack:"

# bash variables in Here-Doc, don't use 'EOF'
# http://stackoverflow.com/questions/4937792/using-variables-inside-a-bash-heredoc
# http://stackoverflow.com/questions/17578073/ssh-and-environment-variables-remote-and-local

echo -e "\nCreating: $REPO_DIR/docker-compose.yml\n"
cat <<EOF > $REPO_DIR/docker-compose.yml
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
    - $DB_DIR/data/db:/data/db
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
    - node
  ports:
    - "3000:3000"
  volumes:
    - $WWW_DIR:/usr/src/app:rw
EOF
cat $REPO_DIR/docker-compose.yml

echo -e "\nCreating: $REPO_DIR/mean.service\n"
cat <<EOF > $REPO_DIR/mean.service
[Unit]
Description=mean
After=etcd.service
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
#KillMode=none
ExecStartPre=-/usr/bin/docker cp mean_mongodb:/data $DBBAK_DIR
ExecStartPre=-/bin/bash -c '/usr/bin/tar -zcvf $DBBAK_DIR/dbbackup_\$\$(date +%%Y-%%m-%%d_%%H-%%M-%%S)_ExecStartPre.tar.gz $DBBAK_DIR/mongodb --remove-files'
ExecStartPre=-/opt/bin/docker-compose --file $REPO_DIR/docker-compose.yml kill
ExecStartPre=-/opt/bin/docker-compose --file $REPO_DIR/docker-compose.yml rm --force
ExecStart=/opt/bin/docker-compose --file $REPO_DIR/docker-compose.yml up --force-recreate
ExecStartPost=/usr/bin/etcdctl set /mean Running
ExecStop=/opt/bin/docker-compose --file $REPO_DIR/docker-compose.yml stop
ExecStopPost=/usr/bin/etcdctl rm /mean
ExecStopPost=-/usr/bin/docker cp mean_mongodb:/data $DBBAK_DIR
ExecStopPost=-/bin/bash -c 'tar -zcvf $DBBAK_DIR/dbbackup_\$\$(date +%%Y-%%m-%%d_%%H-%%M-%%S)_ExecStopPost.tar.gz $DBBAK_DIR/mongodb --remove-files'
Restart=always
#RestartSec=30s

[X-Fleet]
Conflicts=mean.service
EOF
cat $REPO_DIR/mean.service

cd $HOME

echo -e "\n
MEAN stack has successfully built!\n\n\
Run docker-compose with:\n\
  $ docker-compose --file $REPO_DIR/docker-compose.yml build\n\
Run the systemd service with:\n\
  $ cd $REPO_DIR && chmod +x service-start.sh && ./service-start.sh\n\
Stop the systemd service with:\n\
  $ cd $REPO_DIR && chmod +x service-stop.sh && ./service-stop.sh"
echo -e "\nAll done! Exiting..."
