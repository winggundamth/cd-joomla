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
- Make sure local Docker Registry is running by go to http://localhost:8080/repository/index
- Then try to push Docker image to our local Docker Registry with these command

```bash
docker tag ubuntu:14.10 172.17.42.1:5000/ubuntu:14.10
docker push 172.17.42.1:5000/ubuntu:14.10
```
You should see 172.17.42.1:5000/ubuntu:14.10 at Docker Registry UI

#### **Setup GitLab**
```bash
docker run --name gitlab -d -e 'GITLAB_PORT=10080' -e 'GITLAB_SSH_PORT=10022' -p 10022:22 -p 10080:80 -v /var/run/docker.sock:/run/docker.sock -v $(which docker):/bin/docker sameersbn/gitlab
```
- This will take sometimes to complete
- To see setup progress

```bash
docker logs -f gitlab
```
Until it shows something like this
```
INFO success: sidekiq entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)
INFO success: unicorn entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)
INFO success: cron entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)
INFO success: nginx entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)
INFO success: sshd entered RUNNING state, process has stayed up for > than 1 seconds (startsecs)
```

- Test if GitLab working by go to http://localhost:10080
- Login with root/5iveL!fe
- Set new password
- Add your ssh key
- Create these projects
  - joomla
  - joomla-docker
  - joomla-test

#### **Add Joomla Code to GitLab**
```bash
git clone git@git.winginfotech.net:continuous-delivery/cd-joomla-code.git
cd cd-joomla-code
git remote add cd ssh://git@localhost:10022/root/joomla.git
git push cd
cd ..
```

#### **Add Joomla Docker to GitLab**
```bash
git clone git@git.winginfotech.net:continuous-delivery/cd-joomla-docker.git
cd cd-joomla-docker
git remote add cd ssh://git@localhost:10022/root/joomla-docker.git
git push cd
cat joomla/build-files/id_rsa.pub
# copy this public key
cd ..
```
Put your copied public key into [deploy keys](http://localhost:10080/root/joomla/deploy_keys) in your local GitLab at Joomla repository

#### **Add Joomla Test to GitLab**
```bash
git clone git@git.winginfotech.net:continuous-delivery/cd-joomla-test.git
cd cd-joomla-test
git remote add cd ssh://git@localhost:10022/root/joomla-test.git
git push cd
cd ..
```

#### **Setup GitLab CI**
- Go to http://localhost:10080/admin/applications and create New Application then put this information
  - Name: GitLab CI
  - Redirect URI: http://localhost:10081/user_sessions/callback
- Copy Application Id and Secret and replace to below command at GITLAB_APP_ID and GITLAB_APP_SECRET variables

```bash
docker run --name=gitlab-ci -d -p 10081:80 \
-e 'GITLAB_URL=http://172.17.42.1:10080' \
-e 'GITLAB_APP_ID=xxx' \
-e 'GITLAB_APP_SECRET=yyy' \
-v /var/run/docker.sock:/run/docker.sock \
-v $(which docker):/bin/docker sameersbn/gitlab-ci
```
- Test to make sure GitLab CI is running properly by go to http://localhost:10081 and login with your GitLab account then Authorize GitLab CI
- Copy GitLab CI token by open http://localhost:10081/admin/runners

#### **Run GitLab CI Runner**
```bash
git clone git@git.winginfotech.net:continuous-delivery/cd-joomla.git
cd cd-joomla
docker run --name gitlab-ci-runner -it --rm -v $(pwd)/gitlab_ci_runner:/home/gitlab_ci_runner/data sameersbn/gitlab-ci-runner app:setup
# Put URL http://172.17.42.1:10081 and token
docker run --name gitlab-ci-runner -d -v /var/run/docker.sock:/run/docker.sock -v $(which docker):/bin/docker -v $(pwd)/gitlab_ci_runner:/home/gitlab_ci_runner/data sameersbn/gitlab-ci-runner
```
Test to make sure it is running by open http://localhost:10081/admin/runners and it should have one runner listed

#### **Install Robot Framework on GitLab CI Runner**
```bash
docker exec -it gitlab-ci-runner bash
echo 'Acquire::http::Proxy "http://172.17.42.1:3142";' > /etc/apt/apt.conf.d/11proxy
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y firefox xvfb rsync

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
sed -i "/set -e/a \service xvfb start" /app/init
wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py
python get-pip.py
rm get-pip.py
pip install robotframework
pip install robotframework-selenium2library

# Hack to make gitlab-ci-runner user can run docker command
export DOCKER_GROUP_ID=$(ls -l /var/run/docker.sock | awk '{print $4}')
echo "docker:x:$DOCKER_GROUP_ID:gitlab_ci_runner" >> /etc/group

exit
# Restart GitLab CI Runner to apply new configuration
docker restart gitlab-ci-runner
```

#### **Setup Database Backup Server**
Run Nginx container on root of cd-joomla directory
```bash
docker run --name backup -d -p 81:80 -v `pwd`/backup:/usr/share/nginx/html nginx
# Test to make sure nginx container running properly by doing below command to download database backup file
wget http://localhost:81/joomla.sql
rm joomla.sql
```

#### **Setup GitLab to working together**
On cd-joomla root directory
```bash
cat gitlab_ci_runner/.ssh/id_rsa.pub
```
- Add above public key to Local GitLab at Joomla Docker repository as [deploy keys](http://localhost:10080/root/joomla-docker/deploy_keys)
- Go to local GitLab at Joomla Test repository in [deploy keys](http://localhost:10080/root/joomla-test/deploy_keys) and Enable gitlab_ci_runner key to this repository
- Go to http://localhost:10081 to add joomla repository to GitLab CI
- Go to Settings and change these settings
  - GitLab url to project: http://172.17.42.1:10080/root/joomla
- Go to Jobs and click on Deploy (run on success) tab, click on Add a job to add each job one by one as below

**At this time since GitLab still have bug with the order when you add a job. I suggest to add from 05 job first on top then 04 until 01 and when you click on Save Change. It will order from 01 to 05 in List page. This is mandatory to make the jobs properly running with depenpency**

- Name: **01 Build master and develop branch Joomla Docker Image**
- Refs: master, develop

```bash
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
```

- Name: **02 Build master and develop branch Joomla MySQL Docker Image**
- Refs: master, develop

```bash
BUILD_NUMBER=$(cat /tmp/docker-build/joomla/build-number)
echo $BUILD_NUMBER > /tmp/docker-build/mysql/build-number
docker build -t 172.17.42.1:5000/mysql:${BUILD_NUMBER:0:23} /tmp/docker-build/mysql/
docker tag -f 172.17.42.1:5000/mysql:${BUILD_NUMBER:0:23} 172.17.42.1:5000/mysql:latest
docker push 172.17.42.1:5000/mysql:${BUILD_NUMBER:0:23}
docker push 172.17.42.1:5000/mysql:latest
```

- Name: **03 Deploy master branch**
- Refs: master

```bash
BUILD_NUMBER=$(cat /tmp/docker-build/joomla/build-number)
docker ps -a | awk '{print($NF)}' | grep "^mysql$" &> /dev/null && docker rm -f mysql
docker ps -a | awk '{print($NF)}' | grep "^joomla$" &> /dev/null && docker rm -f joomla
docker run -d --name mysql -h mysql -p 3306:3306 172.17.42.1:5000/mysql:${BUILD_NUMBER:0:23}
docker run -d --name joomla -h joomla -p 80:80 -p 443:443 172.17.42.1:5000/joomla:${BUILD_NUMBER:0:23}
```

- Name: **04 Robot Framework with Selenium2Library Test master branch**
- Refs: master

```bash
rm -rf /tmp/robot-test/
mkdir -p /tmp/robot-test/
cd /tmp/robot-test/
if [ -d ".git" ]; then
    git pull ssh://git@172.17.42.1:10022/root/joomla-test.git
else
    git clone ssh://git@172.17.42.1:10022/root/joomla-test.git .
fi
sed -i 's/^${SERVER}.*/${SERVER}         172.17.42.1/g' resource.txt
export DISPLAY=:99
pybot . || EXIT_CODE=$?
rsync -avrzh --progress --exclude .git /tmp/robot-test /home/gitlab_ci_runner/data/$(cat /tmp/docker-build/joomla/build-number)
[ -z $EXIT_CODE ] || exit $EXIT_CODE
```

- Name: **05 Robot Framework with Selenium2Library Test develop branch**
- Refs: develop

```bash
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
export DISPLAY=:99
pybot . || EXIT_CODE=$?
rsync -avrzh --progress --exclude .git /tmp/robot-test /home/gitlab_ci_runner/data/$(cat /tmp/docker-build/joomla/build-number)
docker rm -f mysql-test joomla-test
[ -z $EXIT_CODE ] || exit $EXIT_CODE
```

- Go to Runner page here http://localhost:10081/admin/runners and click on Runner token then click Enable button to make runner assign to joomla repository
- Go to Local GitLab Joomla repository to change GitLab CI URL here http://localhost:10080/root/joomla/services/gitlab_ci/edit and change Project url to http://172.17.42.1:10081/projects/1
- Press Test setting button and go to [local GitLab CI](http://localhost:10081) to see how's it working

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