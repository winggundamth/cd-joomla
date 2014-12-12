# Config Docker to trust local Docker Registry
# Ubuntu
echo 'DOCKER_OPTS="--insecure-registry 172.17.42.1:5000"' | sudo tee -a /etc/default/docker
sudo restart docker
# Boot2Docker
echo 'EXTRA_ARGS="--insecure-registry 172.17.42.1:5000"' | sudo tee -a /var/lib/boot2docker/profile
sudo /etc/init.d/docker restart
mkdir -p /home/docker/git /home/docker/ssh && sudo mount -t vboxsf -o uid=1000,gid=50 git /home/docker/git && sudo mount -t vboxsf -o uid=1000,gid=50 ssh /home/docker/ssh && docker start $(docker ps -aq) && eval $(ssh-agent) && ssh-add

# Pull or update all use Docker Images
docker pull ubuntu:14.10 && \
docker pull registry:latest && \
docker pull atcol/docker-registry-ui:latest && \
docker pull sameersbn/gitlab:7.5.3 && \
docker pull sameersbn/gitlab-ci:5.2.1 && \
docker pull sameersbn/gitlab-ci-runner:5.0.0-1 && \
docker pull nginx:latest

# Setup Docker Registry with UI
docker run --name docker-registry -d -p 5000:5000 registry
docker run --name docker-registry-ui -d -p 8080:8080 -e REG1=http://172.17.42.1:5000/v1/ atcol/docker-registry-ui
# Test by go to http://localhost:8080/repository/index
docker tag ubuntu:14.10 172.17.42.1:5000/ubuntu:14.10
docker push 172.17.42.1:5000/ubuntu:14.10

# Setup Gitlab
docker run --name gitlab -d -e 'GITLAB_PORT=10080' -e 'GITLAB_SSH_PORT=10022' -p 10022:22 -p 10080:80 -v /var/run/docker.sock:/run/docker.sock -v $(which docker):/bin/docker sameersbn/gitlab:7.5.3
# To see setup progress
docker logs gitlab
# http://localhost:10080
# Login with root/5iveL!fe
# Set new password
# Add your ssh key
# Create joomla and joomla docker project

# Add Joomla Code to Gitlab
git pull git@git.winginfotech.net:continuous-delivery/cd-joomla-code.git
cd cd-joomla-code
git remote add cd ssh://git@localhost:10022/root/joomla.git
git push cd

# Add Joomla Docker to Gitlab
git pull git@git.winginfotech.net:continuous-delivery/cd-joomla-docker.git
cd cd-joomla-docker
git remote add cd ssh://git@localhost:10022/root/joomla-docker.git
git push cd
cat joomla/build-files/id_rsa.pub
# Put Joomla Dockerfile into Joomla deploy key

# Setup Gitlab CI
docker run --name=gitlab-ci -d -p 10081:80 -e 'GITLAB_URL=http://172.17.42.1:10080' -v /var/run/docker.sock:/run/docker.sock -v $(which docker):/bin/docker sameersbn/gitlab-ci:5.2.1
# Open http://localhost:10081/admin/runners to see token
# Run Gitlab CI Runner on root cd-joomla directory
docker run --name gitlab-ci-runner -it --rm -v $(pwd)/gitlab_ci_runner:/home/gitlab_ci_runner/data sameersbn/gitlab-ci-runner:5.0.0-1 app:setup
# Put URL http://172.17.42.1:10081 and token
docker run --name gitlab-ci-runner -d -v /var/run/docker.sock:/run/docker.sock -v $(which docker):/bin/docker -v $(pwd)/gitlab_ci_runner:/home/gitlab_ci_runner/data sameersbn/gitlab-ci-runner:5.0.0-1
# Open http://localhost:10081/admin/runners to confirm runner works

# Setup Database Backup Server
# Run Nginx container on root of cd-joomla directory
docker run --name backup -d -p 81:80 -v `pwd`/backup:/usr/share/nginx/html nginx
wget http://localhost:81/joomla.sql

# Setup Gitlab to working together
# On cd-joomla root directory
sudo cat gitlab_ci_runner/.ssh/id_rsa.pub
# Add above public key to Joomla Docker Project deploy key
# Go to http://localhost:10081 to add Joomla Code Project to Gitlab CI
# Go to Setting to config Build Jobs
# Deploy master branch on production server
if [ "$CI_BUILD_REF_NAME" == "master" ]; then
    docker ps -a | awk '{print($NF)}' | grep "^mysql$" &> /dev/null && docker rm -f mysql
    docker ps -a | awk '{print($NF)}' | grep "^joomla$" &> /dev/null && docker rm -f joomla
    docker run -d --name mysql -h mysql -p 3306:3306 172.17.42.1:5000/mysql:master-${CI_BUILD_REF:0:8}
    docker run -d --name joomla -h joomla -p 80:80 -p 443:443 172.17.42.1:5000/joomla:master-${CI_BUILD_REF:0:8}
fi
# Build master branch Joomla MySQL Docker Image
if [ "$CI_BUILD_REF_NAME" == "master" ]; then
    mkdir -p /tmp/docker-build/
    cd /tmp/docker-build/
    ssh-keyscan -p 10022 -H 172.17.42.1 > /home/gitlab_ci_runner/data/.ssh/known_hosts
    if [ -d ".git" ]; then
        git pull ssh://git@172.17.42.1:10022/root/joomla-docker.git
    else
        git clone ssh://git@172.17.42.1:10022/root/joomla-docker.git .
    fi
    cd mysql
    docker build -t 172.17.42.1:5000/mysql .
    docker tag 172.17.42.1:5000/mysql:latest 172.17.42.1:5000/mysql:master-${CI_BUILD_REF:0:8}
    docker push 172.17.42.1:5000/mysql
    docker push 172.17.42.1:5000/mysql:master-${CI_BUILD_REF:0:8}
fi
# Build master branch Joomla Docker Image
if [ "$CI_BUILD_REF_NAME" == "master" ]; then
    mkdir -p /tmp/docker-build/
    cd /tmp/docker-build/
    ssh-keyscan -p 10022 -H 172.17.42.1 > /home/gitlab_ci_runner/data/.ssh/known_hosts
    if [ -d ".git" ]; then
        git pull ssh://git@172.17.42.1:10022/root/joomla-docker.git
    else
        git clone ssh://git@172.17.42.1:10022/root/joomla-docker.git .
    fi
    cd joomla
    docker build -t 172.17.42.1:5000/joomla .
    docker tag 172.17.42.1:5000/joomla:latest 172.17.42.1:5000/joomla:master-${CI_BUILD_REF:0:8}
    docker push 172.17.42.1:5000/joomla
    docker push 172.17.42.1:5000/joomla:master-${CI_BUILD_REF:0:8}
fi
# Change GitLab url to project to http://172.17.42.1:10080/root/joomla
# Go to http://localhost:10080/root/joomla/services/gitlab_ci/edit and change Project url to http://172.17.42.1:10081/projects/1
# Test Setting to see Docker build working http://localhost:10081/admin/builds

# First prepare Joomla
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

# Essential commands
docker build -t mysql .
docker build -t joomla .
docker run -d --name mysql -h mysql -p 3306:3306 mysql
docker run -d --name joomla -h joomla -p 80:80 -p 443:443 joomla