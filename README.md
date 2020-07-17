# jah - Jenkins at home

Jenkins at home (aka. jah) is a lightweight Jenkins installation based on docker containers that will setup a Jenkins environment to develop your CI/CD pipelines.

## Table of Contents

- [What is jah?](#what-is-jah?)
  - [Requirements](#requirements)
  - [How it works?](#how-it-works?)
- [Purpose](#purpose)
- [Install](#install)
  - [Dependencies](#dependencies)
  - [Setup](#setup)
- [Example](#example)
- [Add agents](#add-agents)


## What is jah?
This repository contains the recipes and software to deploy a fully-functional and lightweight Jenkins server for your continuous integration and deployment (CI/CD) needs.
You can also find an example to guide you in using jah.

**Requirements**
- a linux OS running docker engine

**How it works?**
jah runs a Jenkins server in a docker container. When a CICD pipeline job is requested, jah starts a slave docker container (the agent) to run the pipeline. 
The agent's container image needs to be pre-built to include the requirements to run the pipeline, for instance, it requires a golang installation to build and test golang projects.
It is assumed that your projects are located in git, either locally in a filesystem or in a network available server like github. 

## Purpose
jah enables you to implement CI/CD pipelines in very reduced environments without extra hardware or software resources. It is ideal for developers willing to add CI/CD capabilities to their working environments but without too much management hassle.

With jah you can just add your *Jenkinsfile* to your repositories and run your CI pipelines locally from your laptop.

jah is ideal for small startups or development teams, normally just 1 developer and up to 2-3.


## Install
### Dependencies

**Enable docker REST API**
jah needs the docker REST API to trigger pipeline jobs in docker agent containers. If not done yet, you can enable docker's REST API by editing the file `/lib/systemd/system/docker.service` and change the ExecStart line to: 

    ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:4243 -H unix:///var/run/docker.sock

See https://scriptcrunch.com/enable-docker-remote-api for more reference.
You may choose a different port for docker REST API. Once done, restart your docker service and test it works:

    $ curl http://localhost:4243/version


### Setup

**Jenkins server**
jah uses a container running jenkins official image, we name it `jenkins`. To persist data if need to upgrade your container, we create a volume named `jenkins-data`. We may restrict the resource usage for the container, for instance limiting cpu to 0.5 cores, etc.
If your git project repositories are hosted in a local filesystem (say `$HOME/ws/git`), you need to bind mount it. Otherwise, you may remove this mount.
Your Jenkins server UI will be available at `http://localhost:8080`.
```
$ docker pull jenkins/jenkins:lts 
$ docker volume create jenkins-data 
$ docker create --name jenkins --cpus 0.5 \ 
  --mount type=bind,source=$HOME/ws/git,target=/gitserver,readonly \
  --mount source=jenkins-data,target=/var/jenkins_home \
  -p 8080:8080 -p 50000:50000 jenkins/jenkins:lts
```
**Running Jenkins**
Once your jah container running Jenkins server has been created, you may start it with:

    $ docker container start jenkins

when you are not using it, I recommend stopping it to save OS resources.

    $ docker container stop jenkins

all your data will be persisted and ready when you restart Jenkins.

**Configure Jenkins**
The first time you run the Jenkins container, Jenkins initial setup is required. 
An admin user has been created and a password generated. You can examine the jenkins container logs and look for it `$ docker logs jenkins`. Also the password can be found at: `/var/jenkins_home/secrets/initialAdminPassword`. You may use a CLI to access it: `$ docker exec -ti jenkins bash`

Then, go to `http://localhost:8080` in a browser and use `admin` and the password to log in. You may change the password to something more convenient. Follow the set up instructions.

**Install plugins**
Once the basic setup is done, click on `Manage Jenkins` and then `Plugin Manager`. If not installed already, please install the following plugins:

    Docker plugin, v 1.2.0 or higher
    Pipeline, v 2.6 or higher

**Configure docker agent**
Whilst possible, normally we do not want to install all the specific software to build and test projects in the Jenkins server. Instead, we generate a docker image for the jenkins docker agent container that will run the CI/CD pipeline. 
So first, we need to configure Jenkins docker agent. Go to `http://localhost:8080/configureClouds` and add a new cloud.
Configure your docker cloud with the following:

 - Docker Host URI: use the docker REST API URI, ie. tcp://172.17.0.1:4243. You may obtain the IP address with: `$ ip addr show docker0`. Use the port you configured docker to listen to.

Next, you need to configure the **docker agent template**:
- Labels: this is the label you will need to specify in the Jenkinsfile, ie: go-slave.
- Docker image: the image that docker will use to start a container to run the pipeline. See below how to create your own image with the project requirements necessary to run your pipelines. for the time being, you can choose this image from hub.docker.com: `tarancss/go-slave:1.0.0` .
- Volumes from: specify `jenkins` if you are using a local git filesystem as a git server.
-  Pull strategy: specify `Never pull` if your docker agent template image is in your local docker.


## Example
In this example, we will:
- create a git server using a local filesystem
- clone a github repository for a golang project
- set a "local" remote and push the files
- set up a Jenkins pipeline
- trigger a Build of your project's pipeline

**Create a git server**
Initialise a bare git repo in the filesystem mounted in the jenkins container.

    ~/ws/git$ git init --bare hd.git
This command will create an hd.git directory that will act as our git server.

**Clone a repo**
In our working area, clone the example repo:

    /tmp$ git clone https://github.com/tarancss/hd

This will download the repository from github to a directory called hd.

**Set "local" remote and push files**

    /tmp$ cd hd
    /tmp/hd$ git remote add local $HOME/ws/git/hd.git
    /tmp/hd$ git push local master

Now, our "local" git server has the contents of the github repository cloned.

**Set up a Jenkins pipeline**
For this we go to our Jenkins UI. We will click on *New Item*, and select *Pipeline* and name it `hd`.
Just for the example, we configure the following fields:
- Definition: *Pipeline script from SCM*. This tells Jenkins to use the Jenkinsfile included in the repository.
- SCM: *Git*.
- Repository URL: `file:///gitserver/hd.git`. As it is a local filesystem git server we do not require any credentials.
- Branches to build: `master`
- Script Path: `Jenkinsfile`

**Trigger a build**
To trigger a build go to the newly created pipeline view, and click on *Build now*. Jenkins will access the git repository in our local filesystem, clone the repo locally and start a slave container to build the pipeline. Once finished, the slave container is deleted and you can view the log in Jenkins UI.

## Add agents
Every project has its own dependencies that have to be added to the docker agent template image. To help you generate these images, you can use the slave-builder image as a starting point (it has all the requirements for Jenkins docker agents. See the example in the Dockerfile.go-slave file.

    /tmp/hd$ docker build -t slave-builder:1.0.0 -f jenkins-slaves/Dockerfile.builder .
    /tmp/hd$ docker build -t go-slave:1.0.0 -f jenkins-slaves/Dockerfile.go-slave .


