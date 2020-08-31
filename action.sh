#!/bin/bash
set -x
function cleanup(){
	if [ -f /swapfile ];then
		sudo swapoff /swapfile
		sudo rm -rf /swapfile
	fi
	sudo rm -rf /etc/apt/sources.list.d/* /usr/share/dotnet /usr/local/lib/android /opt/ghc
	command -v docker && docker rmi $(docker images -q)
	sudo apt-get -y purge \
		azure-cli \
		ghc* \
		zulu* \
		hhvm \
		llvm* \
		firefox \
		google* \
		dotnet* \
		powershell \
		openjdk* \
		mysql* \
		php*
	sudo apt autoremove --purge -y
}

function init(){
	[ -f sources.list ] && (
		sudo cp -rf sources.list /etc/apt/sources.list
		sudo rm -rf /etc/apt/sources.list.d/* /var/lib/apt/lists/*
		sudo apt-get clean all
	)
	sudo apt-get update
	sudo apt-get install make gcc g++ unzip git file wget python python3 libgnutls28-dev perl libpam0g-dev liblzma-dev libssh2-1-dev libidn2-0-dev libcap-dev libjansson-dev -y
	sudo apt-get install subversion zlib1g-dev build-essential libncursesw5-dev libncurses5-dev gawk gettext libssl-dev libelf-dev ecj qemu-utils mkisofs libglib2.0-dev -y
	sudo apt-get autoremove --purge -y
	sudo apt-get clean
	sudo timedatectl set-timezone Asia/Shanghai
	git config --global user.name "GitHub Action"
	git config --global user.email "action@github.com"
}

function build(){
	if [ -d openwrt ];then
		pushd openwrt
		git pull
		popd
	else
		git clone https://github.com/openwrt/openwrt.git ./openwrt
		[ -f ./feeds.conf.default ] && cat ./feeds.conf.default >> ./openwrt/feeds.conf.default
	fi
	pushd openwrt
	./scripts/feeds update -a
	./scripts/feeds install -a
	[ -d ../patches ] && git am -3 ../patches/*.patch
	[ -f ../files ] && cp -fr ../files ./files
	[ -f ../config ] && cp -fr ../config ./.config
	make defconfig
	make download -j$(nproc) V=s
	make -j$(nproc) V=s
	popd
}

function artifact(){
	mkdir -p ./openwrt-gl-mifi
	cp ./openwrt/bin/targets/ath79/generic/openwrt-ath79-generic-glinet_gl-mifi-squashfs-sysupgrade.bin ./openwrt-gl-mifi
  cp ./openwrt/bin/targets/rockchip/armv8/config.buildinfo ./openwrt-gl-mifi
	zip -r openwrt-gl-mifi.zip ./openwrt-gl-mifi
}

function auto(){
	cleanup
	init
	build
	artifact
}

$@