#!/bin/bash
. /etc/init.d/functions
shopt -s extglob
set -e

# change hostname & write into hosts
function config::hostname(){
    read -p $'Enter new hostname: \n' HN
    /usr/bin/hostnamectl set-hostname ${HN}
    local innerIp=$(hostname -I)
    echo -n "$innerIp $HN" >> /etc/hosts
}

# change ssh port & banned root login with password
function config::sshd(){
    local sshConfig=/etc/ssh/sshd_config
    read -p $'Enter new port: \n' SP
    sed -i "/22/aPort ${SP}" ${sshConfig}
    sed -i '/^Pass/s/yes/no/' ${sshConfig}
    service sshd restart
}

# generate ssh key for login into server
function new::sshkey(){
    local outFile=/root/.ssh/id_rsa
    /usr/bin/ssh-keygen -t rsa -b 4096 -N '' -f ${outFile}
}

# delete hosteye & bcm-agent
function remove::hostapp(){
    service hosteye stop
    service bcm-agent stop
    /usr/sbin/chkconfig --del hosteye
    /usr/sbin/chkconfig --del bcm-agent
    rm -f /etc/init.d/{hosteye,bcm-agent}
    rm -rf /opt/{avalokita,bcm-agent,hosteye,rh}
    test $? -eq 0 && action "uninstall hosteye,bcm-agent service"
}

# stop & disable rpcbind
function remove::service(){
    systemctl stop rpcbind.service
    systemctl disable rpcbind.service
    systemctl mask rpcbind.service
    systemctl stop rpcbind.socket
    systemctl disable rpcbind.socket
    systemctl mask rpcbind.socket
}

# update tsinghua mirrors
function config::repo(){
    baseRepo=/etc/yum.repos.d/CentOS-Base.repo
    cd `echo ${baseRepo%C*}` \
        && action "remove origin base.repo" rm -f !(CentOS-Base.repo|epel.repo) \
        && cd -
    for repoFile in `echo ${baseRepo%C*}`/*;do
        sed -i '/baseurl/s/baidubce.com/tuna.tsinghua.edu.cn/' ${repoFile}
        sed -i '/mirrors/s/http/https/' ${repoFile}
    done
    /bin/yum makecache
}

# written .vimrc & .bashrc
function append::rc(){
    vimStr="set nocompatible\nset backspace=2\nset nu\nset encoding=utf-8\nset ts=4\nset sw=4\nset smarttab\nset ai\nset si\nset hlsearch\nset incsearch\nset expandtab\nsyntax on\nautocmd FileType yaml setlocal ai ts=2 sw=2 expandtab\nfiletype plugin indent on"
    echo -e ${vimStr} > ${HOME}/.vimrc
cat >> ${HOME}/.bashrc <<'EOF'
    export PS1="[\[\e[37m\]\h\[\e[m\] \[\e[33m\]\W\[\e[m\]]\[\e[32m\]\\$\[\e[m\] "
EOF
}

# go env
function new::goenv(){
    goFile=go1.12.7.linux-amd64.tar.gz
    if wget https://studygolang.com/dl/golang/${goFile};then
        tar zxf ${goFile} -C . && rm -f ${goFile} && mv go /usr/local/golang &>/dev/null
    fi
cat >> ${HOME}/.bashrc <<'EOF'
    export PATH=$PATH:/usr/local/golang/bin:$HOME/go/bin
    export GOBIN="${HOME}/go/bin"
    export GOPROXY=https://goproxy.io
EOF
}

# result color
function color::result(){
    echo -e "\e[32m✔   " $1 "\e[m"
}

function main(){
    config::hostname && color::result "Config Hostname"
    config::sshd && color::result "Config Sshd"
    new::sshkey && color::result "New Sshkey"
    remove::hostapp
    remove::service  && color::result "Remove hostapp & service of Baidu Cloud"
    config::repo  && color::result "Config Repo"
    append::rc  && color::result "Append Rc"
    new::goenv  && color::result "New GO env"
}

main "$@"
