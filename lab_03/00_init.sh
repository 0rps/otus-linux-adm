#!/bin/bash

mkdir -p ~root/.ssh
cp ~vagrant/.ssh/auth* ~root/.ssh
yum install -y lvm2 xfsdump tmux bash-completion bash-completion-extras
