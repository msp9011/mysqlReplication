# mysqlReplication
To configure Mysql master-master replication

Note: "Mysql_repli_final" is only for fresh MASTER-MASTER configuration.##

The following 3 steps need to do before running Mysql_repli_final script

  - Both server must have sshpass installed.
  - Both MySQL should have  grant all privilege with grant option for root@<IP>
  - Login from MASTER1 to MASTER2  through ssh . ( to add RSA key )


1. INSTALL sshpass : Run the following in both servers

wget http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm
rpm -ivh epel-release-6-8.noarch.rpm
yum install sshpass


2. GRANT PRIVILEGE FOR ROOT

  2.1 Run the following in mysql of MASTER1. ( replace 192.168.1.185 with your MASTER1 IP)


>grant all on *.* to 'root'@'192.168.1.185' identified by 'root' with grant option;
>flush privileges;

  2.2 Run the following in mysql of MASTER2. ( replace 192.168.1.186 with yours MASTER2 IP)


>grant all on *.* to 'root'@'192.168.1.186' identified by 'root' with grant option;
>flush privileges;



3. Login to MASTER2 from MASTER1 through SSH: run the following in MASTER1 ( replace 192.168.1.186 with yours MASTER2 IP)

ssh 192.168.1.186
><enter root password>
exit
