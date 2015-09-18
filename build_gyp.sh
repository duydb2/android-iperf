#!/bin/bash

SCRIPT_PATH=$(dirname $(readlink -f $0))
export PROJECT_PATH=$SCRIPT_PATH

install_android_toolchain() {
	if [ ! -d $1 ]; then
		mkdir -p $1
		$2/build/tools/make-standalone-toolchain.sh \
			--toolchain=arm-linux-androideabi-4.8 \
			--arch=arm \
			--stl=stlport \
			--install-dir=$1\
			--platform=android-19
	fi
	prefix=arm-linux-androideabi
	# SYSROOT CPPPATH LIBPATH
	export PATH=$1/bin:$PATH
	export AR=$prefix-ar
	export CC=$prefix-gcc
	export CXX=$prefix-g++
	export LINK=$prefix-g++
	export LD=$prefix-ld
	export NM=$prefix-nm
	export RANLIB=$prefix-ranlib
	export READELF=$prefix-readelf
}

install_libpcap () {
	PCAP_SRC_DIR=$1/tmp/libpcap-1.7.4
	# build libpcap
	[ -d $PCAP_SRC_DIR ] ||  (mkdir -p $(dirname $PCAP_SRC_DIR) && echo "Cache libpcap from Internet to $PCAP_SRC_DIR" && curl http://www.tcpdump.org/release/libpcap-1.7.4.tar.gz | tar -xz -C $(dirname $PCAP_SRC_DIR))
	if [ ! -f $PCAP_SRC_DIR/libpcap.a ]; then
		pushd $PCAP_SRC_DIR
		./configure  CFLAGS=' -Dlinux -D__GLIBC__' --prefix=$TOOLCHAIN/sysroot/usr --host=arm-linux --with-pcap=linux ac_cv_linux_vers=2
		make V=1
		make install
		popd
	fi
	return 0
}

build_android() {
	OUT=$1/gyp_build_android
	export TOOLCHAIN=/tmp/android-toolchain
	export PLATFORM=android 
	install_android_toolchain $TOOLCHAIN $NDK_ROOT
	./configure --host=arm-linux \
		CFLAGS='-Dlinux -DANDROID -D__GLIBC__ -D_NDK_MATH_NO_SOFTFP=0 -std=gnu99' \
		LDFLAGS='-static  -static-libgcc -static-libstdc++' \
		--enable-static --prefix=`pwd`/install --with-sysroot=/tmp/android-toolchain/sysroot/
	make V=1
	# make install
}

run_android () {
	adb push $SCRIPT_PATH/src/iperf3 /data/local/tmp/iperf3
	# 	adb forward tcp:12345 tcp:12345
	# 	adb shell busybox nc -lp 12345 -e "$@" &
	# 	sleep 1s
	# 	exec nc -q 1 localhost 12345
	adb shell '/data/local/tmp/iperf3'
}


build () {
	build_$1 $SCRIPT_PATH/out
}

run () {
	run_$1 $SCRIPT_PATH/out
	return 0
}

all () {
	build android
	run android
}

cd $SCRIPT_PATH
echo "Project directory:  $SCRIPT_PATH" 
echo "build project with: $@ 					" 

if [ "$1" == "" ]; then
	all $@
else 
	$@
fi
