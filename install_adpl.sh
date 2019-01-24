#!/bin/bash
if [ $UID -ne 0 ] ; then
  echo "This installer requires superuser privileges to run."
  echo "Please run it with sudo or login as root to run. Thx."
  exit 1
fi


usage()
{
    echo "Usage: $0 -i -o <orchestrator IP> -p <package name> -f -m  [-h]
	i: Installing Dependencies
	o: Orchestrator IP
	p: Avocado package 
	f: Port 8900	
	m: Selinux/Apparmor
	h : Help"
    exit 1    
}

orch_ip=""
attr='ORCHURL='

#Platform naming for comparison and for script output messages
deb_ubu="Debian/Ubuntu"
redhat_centos="Redhat/Centos"
oracle_linux="OracleLinux"
amazon_linux="Amazon Linux"

PACKAGE_NAME="avocado"
declare -a DEBIAN_DEPENDENCIES_ARRAY=("libcurl3" "libnss3" "libnspr4") 
declare -a RPM_DEPENDENCIES_ARRAY=("curl" "openssl" "nss") 

DEBIAN_INSTALL_COMMAND="dpkg -i"
RPM_INSTALL_COMMAND="rpm -ivh" #THIS COMMAND WILL NOT AUTO-INSTALL DEPENDENCIES

if [ "$#" -eq 0 ]; then
	usage
fi

fn_distro(){
arch=$(uname -m)
kernel=$(uname -r)
if [ -f /etc/debian_version -o -f /etc/debian_release ]; then
        os="$deb_ubu"
        echo "Platform $os detected"
        filename="$PACKAGE_NAME""_""$VERSION_NUMBER"
elif [ -f /etc/oracle-release -o -f /etc/oracle_release ]; then
        os="$oracle_linux"
        echo "Platform $os detected"
       filename="$PACKAGE_NAME-$VERSION_NUMBER"
elif [ -f /etc/redhat-release -o -f /etc/redhat_version ]; then
        os="$redhat_centos"
        echo "Platform $os detected"
       filename="$PACKAGE_NAME-$VERSION_NUMBER"
elif [ -f /etc/system-release ]; then
	grep "Amazon Linux" /etc/system-release > /dev/null
	amazonoschk=`echo $?`
	if [ "$amazonoschk" -eq 0 ]
	then
         os="$amazon_linux"
         echo "Platform $os detected"
         filename="$PACKAGE_NAME-$VERSION_NUMBER"
	else
	 echo "OS does not support"
	 exit 1
	fi
else
        os="$(uname -s) $(uname -r)"
        echo "Error: Script $0 supports only Redhat, OracleLinux and Debian distributions & need access to /etc/* files"
        exit 1
fi
}
#Installing dependenies
install_debian_dependencies(){
        for i in "${DEBIAN_DEPENDENCIES_ARRAY[@]}"
        do
           echo "Now installing $i (on $os)"
           deb_dep_install_command="apt-get -y install $i"
           echo "Executing command: $deb_dep_install_command"
           ($deb_dep_install_command)
           ret_val=$?
           if  [ $ret_val = '0' ]
                then
                        echo "Installed depedency package $i"
                else
                        echo "Error installing depedency package, executed command: $deb_dep_install_command"
                        exit $((ret_val))
                fi
        done
}
install_rpm_dependencies(){
        for i in "${RPM_DEPENDENCIES_ARRAY[@]}"
        do
           echo "Now installing $i (on $os)"
           rpm_dep_install_command="yum -y install $i"
           echo "Executing command: $rpm_dep_install_command"
           ($rpm_dep_install_command)
           ret_val=$?
           if  [ $ret_val = '0' ]
                then
                        echo "Installed depedency package $i"
                else
                        echo "Error installing depedency package, executed command: $rpm_dep_install_command"
                        exit $((ret_val))
                fi
        done
}

#install dependency
install_dep(){
	if [[ "$os" == "Debian/Ubuntu" ]];
	then
	    install_debian_dependencies
	elif [[ "$os" == "Redhat/Centos" ]];
	then
	    install_rpm_dependencies
	elif [[ "$os" == "OracleLinux" ]];
	then
	    install_rpm_dependencies
	elif [[ "$os" == "Amazon Linux" ]];
        then
	    install_rpm_dependencies
	fi
}

#avocado rpm Package installation 
rpmpkg(){
export ORCHURL=https://${orch_ip}:8443/orchestrator/ 
$RPM_INSTALL_COMMAND $pkgname
}

#avocado deb Package installation 
debpkg(){
export ORCHURL=https://${orch_ip}:8443/orchestrator/ 
$DEBIAN_INSTALL_COMMAND $pkgname
}

avcdpkg(){
if [[ "$os" == "Debian/Ubuntu" ]];
  then
	debpkg
  elif [[ "$os" == "Redhat/Centos" ]];
    then
	rpmpkg
  elif [[ "$os" == "OracleLinux" ]];
    then
	rpmpkg
  elif [[ "$os" == "Amazon Linux" ]];
    then
	rpmpkg
fi
}

#Port adding function
add_port_firewall(){
if [[ `firewall-cmd --state` = running ]]
then
        firewall-cmd --zone=public --add-port=8900/tcp --permanent > /dev/null
        firewall-cmd --reload > /dev/null
        firewall-cmd --list-all | grep -w 8900/tcp
else
      echo "firewall_status=inactive"
fi
}

add_port_iptable(){
	/sbin/service iptables status > /dev/null 2>&1
	if [ $? = 0 ]; then
		echo "iptable service is running"
		iptables -nL | grep 8900 > /dev/null
		portcheck=$?
		if [ $portcheck -eq 0 ]; then
			echo "port 8900 is present in iptable rule"
		else
			iptables -I INPUT -p tcp -m tcp --dport 8900 -j ACCEPT
			service iptables save
			service iptables restart
		fi
	else
		echo "iptables service is not running"
	fi
}

add_port_ufw(){
ufw status | grep -qw active
act_val=$?
if  [ $act_val = '1' ]
  then
   echo "ufw is disabled"
  else
   ufw allow 8900/tcp > /dev/null
   ufw status numbered | grep 8900 > /dev/null
   portstatus=$?
    if  [ $portstatus = '0' ]
     then
     echo "TCP Port 8900 is enabled"
    fi
fi
}

add_port(){
if [[ "$os" == "Debian/Ubuntu" ]];
  then
	add_port_ufw
  elif [[ "$os" == "Redhat/Centos" ]];
    then
	add_port_firewall
  elif [[ "$os" == "OracleLinux" ]];
    then
	add_port_firewall
  elif [[ "$os" == "Amazon Linux" ]];
    then
	add_port_iptable
fi
}

disable_selinux(){
if test -e /etc/sysconfig/selinux ; then
  selinuxstatus=`/usr/sbin/getenforce`
	if [ $selinuxstatus == "Permissive" ]
	  then
  	      echo "SELinux is in $selinuxstatus mode"
 	elif [ $selinuxstatus == "Disabled" ]
	  then
	      echo "SELinux is in $selinuxstatus mode"
	elif [ $selinuxstatus == "Enforcing" ]
	  then
	      permissivemodecmd=`/usr/sbin/setenforce 0`
	      echo "Warning: SELinux is in $selinuxstatus mode"
	      echo "Changing $selinuxstatus mode to Permissive mode..."
		$permissivemodecmd
	      echo "`/usr/sbin/getenforce` mode is set"
		grep ^SELINUX=enforcing /etc/selinux/config > /dev/null
		enforcechk=`echo $?`
		if [ "$enforcechk" -eq 0 ]
		  then
		      sed -i 's/^SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
		fi
	fi
fi
}

disable_apparmor(){
  service apparmor status | grep "Active: active" > /dev/null
  appst=`echo $?`
	if [ "$appst" -eq 0 ]
	  then
	      echo "Warning : Apparmor service is active"
	      echo "Disabling apparmor service"
		service apparmor stop
		invoke-rc.d apparmor stop
		update-rc.d -f apparmor remove
		if [ -f /etc/apparmor.d/usr.sbin.mysqld ]
	  	   then
		    ln -s /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/disable/
		    apparmor_parser -R /etc/apparmor.d/usr.sbin.mysqld
		fi
	  else
	     echo "Apparmor service is inactive"
	fi
}

disable_security_module(){
if [[ "$os" == "Debian/Ubuntu" ]];
  then
	disable_apparmor
elif [[ "$os" == "Redhat/Centos" ]];
  then
	disable_selinux
elif [[ "$os" == "OracleLinux" ]];
  then
	disable_selinux
elif [[ "$os" == "Amazon Linux" ]];
  then
	disable_selinux
fi
}

fn_distro
while getopts ":hio:p:fm" opt; do
  case ${opt} in
    h ) # process option a
	usage
	exit 1
      ;;
    i ) # process option l
        echo "installing dependecies on $os"
        install_dep
     ;;
    o ) # Getting orchestrator ip
        orch_ip=$OPTARG
     ;;
    p ) # Getting package and installing
	pkgname=$OPTARG
	avcdpkg
     ;;
   f )
	grep 6 /etc/redhat-release &> /dev/null
	if [ $? = 0 ]
	  then
		add_port_iptable
	  else
        	add_port
	fi
      ;;
   m )
      disable_security_module
     ;;
   \? )
	usage
	exit 1
      ;;
    :)
    echo "Option -$OPTARG requires an argument."
    usage 
    exit 1    
  esac
done

