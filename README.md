Practice for Joomla Continuous Delivery with Docker
----------------------------------------------------

#### **Prerequisite**
* You must have Docker install
* You must have apt-cacher-ng run on port 3142 with command

```bash
docker run -d --name apt-cacher-ng -p 3142:80 tianon/apt-cacher-ng
```

#### **Config Docker to trust local Docker Registry**
**Ubuntu**
```bash
echo 'DOCKER_OPTS="--insecure-registry 172.17.42.1:5000"' | sudo tee -a /etc/default/docker
sudo restart docker
```
**Boot2Docker**
```bash
echo 'EXTRA_ARGS="--insecure-registry 172.17.42.1:5000"' | sudo tee -a /var/lib/boot2docker/profile
sudo /etc/init.d/docker restart
mkdir -p /home/docker/git /home/docker/ssh && sudo mount -t vboxsf -o uid=1000,gid=50 git /home/docker/git && sudo mount -t vboxsf -o uid=1000,gid=50 ssh /home/docker/ssh && docker start $(docker ps -aq) && eval $(ssh-agent) && ssh-add
```

#### **Pull or update all use Docker Images**
```bash
docker pull ubuntu:14.10 && \
docker pull registry:latest && \
docker pull atcol/docker-registry-ui:latest && \
docker pull sameersbn/gitlab:latest && \
docker pull sameersbn/gitlab-ci:latest && \
docker pull sameersbn/gitlab-ci-runner:latest && \
docker pull nginx:latest
```

#### **Setup Docker Registry with UI**
```bash
docker run --name docker-registry -d -p 5000:5000 registry
docker run --name docker-registry-ui -d -p 8080:8080 -e REG1=http://172.17.42.1:5000/v1/ atcol/docker-registry-ui
```
Test by go to http://localhost:8080/repository/index
Then test if local docker registry working
```bash
docker tag ubuntu:14.10 172.17.42.1:5000/ubuntu:14.10
docker push 172.17.42.1:5000/ubuntu:14.10
```
You should see 172.17.42.1:5000/ubuntu:14.10 at Docker Registry UI

#### **Setup Gitlab**
```bash
docker run --name gitlab -d -e 'GITLAB_PORT=10080' -e 'GITLAB_SSH_PORT=10022' -p 10022:22 -p 10080:80 -v /var/run/docker.sock:/run/docker.sock -v $(which docker):/bin/docker sameersbn/gitlab:7.5.3
```
This will take sometimes to complete

To see setup progress
```bash
docker logs gitlab
```

- Test if Gitlab working by go to http://localhost:10080
- Login with root/5iveL!fe
- Set new password
- Add your ssh key
- Create *joomla*, *joomla docker* and *joomla test* project

#### **Add Joomla Code to Gitlab**
```bash
git pull git@git.winginfotech.net:continuous-delivery/cd-joomla-code.git
cd cd-joomla-code
git remote add cd ssh://git@localhost:10022/root/joomla.git
git push cd
```

#### **Add Joomla Docker to Gitlab**
```bash
git pull git@git.winginfotech.net:continuous-delivery/cd-joomla-docker.git
cd cd-joomla-docker
git remote add cd ssh://git@localhost:10022/root/joomla-docker.git
git push cd
cat joomla/build-files/id_rsa.pub
```
Put Joomla Dockerfile into Joomla deploy key

#### **Add Joomla Test to Gitlab**
```bash
git pull git@git.winginfotech.net:continuous-delivery/cd-joomla-test.git
cd cd-joomla-test
git remote add cd ssh://git@localhost:10022/root/joomla-test.git
git push cd
```

#### **Setup Gitlab CI**
```bash
docker run --name=gitlab-ci -d -p 10081:80 -e 'GITLAB_URL=http://172.17.42.1:10080' -v /var/run/docker.sock:/run/docker.sock -v $(which docker):/bin/docker sameersbn/gitlab-ci:5.2.1
```
Test and get token by open http://localhost:10081/admin/runners

#### **Run Gitlab CI Runner on root cd-joomla directory**
```bash
git pull git@git.winginfotech.net:continuous-delivery/cd-joomla-code.git
cd cd-joomla-code
docker run --name gitlab-ci-runner -it --rm -v $(pwd)/gitlab_ci_runner:/home/gitlab_ci_runner/data sameersbn/gitlab-ci-runner:5.0.0-1 app:setup
# Put URL http://172.17.42.1:10081 and token
docker run --name gitlab-ci-runner -d -v /var/run/docker.sock:/run/docker.sock -v $(which docker):/bin/docker -v $(pwd)/gitlab_ci_runner:/home/gitlab_ci_runner/data sameersbn/gitlab-ci-runner:5.0.0-1
```
Test by open http://localhost:10081/admin/runners to confirm runner works

#### **Install Robot Framework on CI Runner**
```bash
docker exec -it gitlab-ci-runner /bin/bash
echo 'Acquire::http::Proxy "http://172.17.42.1:3142";' > /etc/apt/apt.conf.d/11proxy
apt-get update
apt-get install -y firefox xvfb

cat <<'EOF' > /etc/init.d/xvfb
###############################################################################
#! /bin/sh
#
# skeleton      example file to build /etc/init.d/ scripts.
#               This file should be used to construct scripts for /etc/init.d.
#
#               Written by Miquel van Smoorenburg <miquels@cistron.nl>.
#               Modified for Debian
#               by Ian Murdock <imurdock@gnu.ai.mit.edu>.
#               Further changes by Javier Fernandez-Sanguino <jfs@debian.org>
#
# Version:      @(#)skeleton  1.9  26-Feb-2001  miquels@cistron.nl
#
### BEGIN INIT INFO
# Provides:          xvfb
# Required-Start:    $remote_fs $network $named
# Required-Stop:     $remote_fs $network $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start/stop xvfb
# Description:       Start/stop xvfb daemon and its configured
#                    subprocesses.
### END INIT INFO

XVFB=/usr/bin/Xvfb
XVFBARGS=":99 -screen 0 1024x768x24 -fbdir /var/run -ac"
PIDFILE=/var/run/xvfb.pid
case "$1" in
  start)
    echo -n "Starting virtual X frame buffer: Xvfb"
    start-stop-daemon --start --quiet --pidfile $PIDFILE --make-pidfile --background --exec $XVFB -- $XVFBARGS
    echo "."
    ;;
  stop)
    echo -n "Stopping virtual X frame buffer: Xvfb"
    start-stop-daemon --stop --quiet --pidfile $PIDFILE
    echo "."
    ;;
  restart)
    $0 stop
    $0 start
    ;;
  *)
        echo "Usage: /etc/init.d/xvfb {start|stop|restart}"
        exit 1
esac

exit 0
EOF

chmod +x /etc/init.d/xvfb
wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py
python get-pip.py
rm get-pip.py
pip install robotframework
pip install robotframework-selenium2library
exit
```

#### **Setup Database Backup Server**
Run Nginx container on root of cd-joomla directory
```bash
docker run --name backup -d -p 81:80 -v `pwd`/backup:/usr/share/nginx/html nginx
wget http://localhost:81/joomla.sql
```

#### **Setup Gitlab to working together**
On cd-joomla root directory
```bash
sudo cat gitlab_ci_runner/.ssh/id_rsa.pub
```
- Add above public key to Joomla Docker Project deploy key
- Go to http://localhost:10081 to add Joomla Code Project to Gitlab CI
- Go to Setting to config Build Jobs

**01 Build master branch Joomla Docker Image**
```bash
if [ "$CI_BUILD_REF_NAME" == "master" ] || [ "$CI_BUILD_REF_NAME" == "develop" ]; then
    CI_TIMESTAMP=$(date +%Y%m%d%H%M%S)
    mkdir -p /tmp/docker-build/
    cd /tmp/docker-build/
    ssh-keyscan -p 10022 -H 172.17.42.1 > /home/gitlab_ci_runner/data/.ssh/known_hosts
    if [ -d ".git" ]; then
        git pull ssh://git@172.17.42.1:10022/root/joomla-docker.git
    else
        git clone ssh://git@172.17.42.1:10022/root/joomla-docker.git .
    fi
    rm -rf /tmp/docker-build/joomla/joomla
    cp -a /home/gitlab_ci_runner/gitlab-ci-runner/tmp/builds/project-1 /tmp/docker-build/joomla/joomla
    echo $CI_TIMESTAMP-$CI_BUILD_REF > /tmp/docker-build/joomla/build-number
    docker build -t 172.17.42.1:5000/joomla:$CI_TIMESTAMP-${CI_BUILD_REF:0:8} /tmp/docker-build/joomla/
    docker tag -f 172.17.42.1:5000/joomla:$CI_TIMESTAMP-${CI_BUILD_REF:0:8} 172.17.42.1:5000/joomla:latest
    docker push 172.17.42.1:5000/joomla:$CI_TIMESTAMP-${CI_BUILD_REF:0:8}
    docker push 172.17.42.1:5000/joomla:latest
fi
```

**02 Build master branch Joomla MySQL Docker Image**
```bash
if [ "$CI_BUILD_REF_NAME" == "master" ] || [ "$CI_BUILD_REF_NAME" == "develop" ]; then
    BUILD_NUMBER=$(cat /tmp/docker-build/joomla/build-number)
    echo $BUILD_NUMBER > /tmp/docker-build/mysql/build-number
    docker build -t 172.17.42.1:5000/mysql:${BUILD_NUMBER:0:23} /tmp/docker-build/mysql/
    docker tag -f 172.17.42.1:5000/mysql:${BUILD_NUMBER:0:23} 172.17.42.1:5000/mysql:latest
    docker push 172.17.42.1:5000/mysql:${BUILD_NUMBER:0:23}
    docker push 172.17.42.1:5000/mysql:latest
fi
```

**03 Deploy master branch**
```bash
if [ "$CI_BUILD_REF_NAME" == "master" ]; then
    BUILD_NUMBER=$(cat /tmp/docker-build/joomla/build-number)
    docker ps -a | awk '{print($NF)}' | grep "^mysql$" &> /dev/null && docker rm -f mysql
    docker ps -a | awk '{print($NF)}' | grep "^joomla$" &> /dev/null && docker rm -f joomla
    docker run -d --name mysql -h mysql -p 3306:3306 172.17.42.1:5000/mysql:${BUILD_NUMBER:0:23}
    docker run -d --name joomla -h joomla -p 80:80 -p 443:443 172.17.42.1:5000/joomla:${BUILD_NUMBER:0:23}
fi
```

**04 Robot Framework with Selenium2Library Test master branch**
```bash
if [ "$CI_BUILD_REF_NAME" == "master" ]; then
    rm -rf /tmp/robot-test/
    mkdir -p /tmp/robot-test/
    cd /tmp/robot-test/
    if [ -d ".git" ]; then
        git pull ssh://git@172.17.42.1:10022/root/joomla-test.git
    else
        git clone ssh://git@172.17.42.1:10022/root/joomla-test.git .
    fi
    sed -i 's/^${SERVER}.*/${SERVER}         172.17.42.1/g' resource.txt
    service xvfb start
    export DISPLAY=:99
    pybot . || EXIT_CODE=$?
    cp -a /tmp/robot-test /home/gitlab_ci_runner/data/$(cat /tmp/docker-build/joomla/build-number)
    [ -z $EXIT_CODE ] || exit $EXIT_CODE
fi
```

**05 Robot Framework with Selenium2Library Test develop branch**
```bash
if [ "$CI_BUILD_REF_NAME" == "develop" ]; then
    BUILD_NUMBER=$(cat /tmp/docker-build/joomla/build-number)
    docker ps -a | awk '{print($NF)}' | grep "^mysql-test$" &> /dev/null && docker rm -f mysql-test
    docker ps -a | awk '{print($NF)}' | grep "^joomla-test$" &> /dev/null && docker rm -f joomla-test
    docker run -d --name mysql-test -h mysql -p 3310:3306 172.17.42.1:5000/mysql:${BUILD_NUMBER:0:23}
    docker run -d --name joomla-test -h joomla -p 8010:80 -e 'MYSQL_PORT=3310' 172.17.42.1:5000/joomla:${BUILD_NUMBER:0:23}
    rm -rf /tmp/robot-test/
    mkdir -p /tmp/robot-test/
    cd /tmp/robot-test/
    if [ -d ".git" ]; then
        git pull ssh://git@172.17.42.1:10022/root/joomla-test.git
    else
        git clone ssh://git@172.17.42.1:10022/root/joomla-test.git .
    fi
    sed -i 's/^${SERVER}.*/${SERVER}         172.17.42.1:8010/g' resource.txt
    service xvfb start
    export DISPLAY=:99
    pybot . || EXIT_CODE=$?
    cp -a /tmp/robot-test /home/gitlab_ci_runner/data/$(cat /tmp/docker-build/joomla/build-number)
    docker rm -f mysql-test joomla-test
    [ -z $EXIT_CODE ] || exit $EXIT_CODE
fi
```

- Change GitLab url to project to http://172.17.42.1:10080/root/joomla
- Go to http://localhost:10080/root/joomla/services/gitlab_ci/edit and change Project url to http://172.17.42.1:10081/projects/1
- Test Setting to see Docker build working

### ETC

#### **First prepare Joomla**
```bash
mkdir -p joomla
cd joomla
wget https://github.com/joomla/joomla-cms/releases/download/3.3.6/Joomla_3.3.6-Stable-Full_Package.zip
unzip Joomla_*.zip
git config --global user.name "Administrator"
git config --global user.email "admin@example.com"
git init
git remote add origin ssh://git@172.17.42.1:10022/root/joomla.git
git add .
git commit -m "Initial Joomla Project"
git push -u origin master
```

#### **Essential commands**
```bash
docker build -t mysql .
docker build -t joomla .
```

#### **Production**
```bash
docker run -d --name mysql -h mysql -p 3306:3306 mysql
docker run -d --name joomla -h joomla -p 80:80 joomla
```

#### **Dev**
```bash
docker run -d --name mysql-dev -h mysql -p 3307:3306 172.17.42.1:5000/mysql
docker run -d --name joomla-dev -v $(pwd)/cd-joomla-code:/var/www/html -h joomla -p 8888:80 -e 'MYSQL_PORT=3307' 172.17.42.1:5000/joomla
```