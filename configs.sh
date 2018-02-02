#!/usr/bin/env bash

# Chnaged IP's to suit internal network
#declaration of the variables which are used in this file
puppetmasterip="192.13.128.10"                                       # replace with the IP of your puppetmaster
puppetagentip="192.13.128.11"                                        # replace with the  IP of your puppetagent
puppetmasterhost="pmaster.puppet.com"                                # hostname of the puppetmaster, you can change it to your own preferences
puppetagenthost="pagent.puppet.com"                               # hostname of the puppetagent, you can change it to your own preferences
puppetmasterhostline="$puppetmasterip $puppetmasterhost"            # creates a long string with the Puppetmaster IP address and hostname so it can be added to the hosts file. 
puppetconf="/etc/puppetlabs/puppet/puppet.conf"                     # the path where the the puppet.conf file is located
hostfile="/etc/hosts"                                               # the path where the hosts file is located
IP=$( ifconfig enp0s8 | grep inet | grep -v inet6 | cut -c 14-25)   # gets the ip address of the enp0s8 interface which we can use to distinguish the puppet master and agent 
memoryline=9                                                        # the line number of the wrong memory line in the puppetserver file which will be removed.

#installing the essentials
yum install -y vim # not required for the master/agent connection. I just like using it. 
yum install -y tree # not required for the master/agent connection. I just like using it. 
yum install -y iptables-services # required to save the firewall rules
yum install -y firewalld # required to be able to add the firewall rules

#flush all exisiting firewall rules
sudo iptables -F

#adding the firewall rules
sudo firewall-cmd --add-port=8140/tcp --permanent # the port which the puppetmaster uses to communicate through
sudo firewall-cmd --add-port=80/tcp --permanent   # not required but I included it to test my apache webserver module
sudo firewall-cmd --add-port=433/tcp --permanent  # not required but I included it to test my apache webserver module

#saves the new firewall rules
sudo service iptables save

#updating the gpg keys for puppet because the box comes with outdated gpg keys. 
curl --remote-name --location https://yum.puppetlabs.com/RPM-GPG-KEY-puppet
rpm --import RPM-GPG-KEY-puppet

#deleting the puppet configuration file if present
if [ -f $puppetconf ] ; then # searches for the puppet.conf file
    rm $puppetconf           # if it's found it will get removed by the utilisation of this line
fi

#creating and adding the master to the puppet.conf file
echo "[main]" >> /etc/puppetlabs/puppet/puppet.conf # 
echo "server = $puppetmasterhost" >> /etc/puppetlabs/puppet/puppet.conf

#adding the master to the host file if it doesn't exist. Does nothing if it already exists.
grep -qF "$puppetmasterhostline" "$hostfile" || echo "$puppetmasterhostline" | sudo tee --append "$hostfile"

#configures the puppetmaster
if [[ $IP = $puppetmasterip ]]; then           # gets the IP address of the puppetmaster
    hostnamectl set-hostname $puppetmasterhost # sets master hostname
    yum install -y puppetserver                # installs the puppetserver
    sed "${memoryline}d" /etc/sysconfig/puppetserver  # deletes the old memory of the puppetserver file, by default the memory makes it impossible for the puppetserver to run
    echo "JAVA_ARGS='"-Xms512m -Xmx512m -XX:MaxPermSize=256m"'" >> /etc/sysconfig/puppetserver # adds the new memory to the puppetserver file so it can run
    sudo systemctl start puppetserver          #starts the puppetserver
    
#configures the puppet agent 
elif [[ $IP = $puppetagentip ]]; then          # gets the IP address of the puppetagent
    hostnamectl set-hostname $puppetagenthost  # sets the agents hostname
    yum install -y puppet                      # installs puppet, it's not required because the box comes with Puppet by default but just to be sure...
    sudo su                                    # logs in as root
    puppet agent -t                            # requests certificate from the puppetmaster
fi
