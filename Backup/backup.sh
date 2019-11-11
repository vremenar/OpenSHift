#!/bin/bash

# Log start of backup
echo -e "[$(date +%x-%X)] Backup starting"

# Set folders
BACKUP_DIR="/opt/backup"
SYS_BACKUP_DIR="$BACKUP_DIR/system/$(date +%Y_%m_%d)"
APP_BACKUP_DIR="$BACKUP_DIR/applications/$(date +%Y_%m_%d)"

# Create folders
mkdir -p "${SYS_BACKUP_DIR}/etc/origin/"
mkdir -p "${SYS_BACKUP_DIR}/etc/sysconfig/"
mkdir -p "${SYS_BACKUP_DIR}/etc/pki/ca-trust/"
mkdir -p "${SYS_BACKUP_DIR}/etc/docker/certs.d/"
mkdir -p "${SYS_BACKUP_DIR}/etc/etcd/"

echo -e "[$(date +%x-%X)] Starting filesystem backup"

# Backup OpenShift
cp -aR /etc/origin/* ${SYS_BACKUP_DIR}/etc/origin/

# Backup Container Network Interface
cp -aR /etc/cni/* ${SYS_BACKUP_DIR}/etc/cni/

# Backup othe relevant system files
cp -aR /etc/dnsmasq* ${SYS_BACKUP_DIR}/etc/
cp -aR /etc/sysconfig/* ${SYS_BACKUP_DIR}/etc/sysconfig/

# Backup PKI trusts
cp -aR /etc/pki/ca-trust/* ${SYS_BACKUP_DIR}/etc/pki/ca-trust/

# Backup Docker trusted registries
cp -aR /etc/docker/certs.d/* ${SYS_BACKUP_DIR}/etc/docker/certs.d/

# Backup etcd
cp -aR /etc/etcd/* ${SYS_BACKUP_DIR}/etc/etcd/

# Backup list of installed packages
rpm -qa | sort | tee ${SYS_BACKUP_DIR}/packages.log > /dev/null 2>&1

echo -e "[$(date +%x-%X)] Starting OpenShift backup"

# Login to OpenShift
oc login -u system:admin > /dev/null 2>&1

# Backup all cluster-wide resources
mkdir -p "${APP_BACKUP_DIR}"
RESOURCES=$(oc api-resources -o name --namespaced=false --verbs=get list | cut -d'.' -f1)
for R in $RESOURCES
do
    echo -e "[$(date +%x-%X)] OpenShift cluster ${R} resource backup"
    oc get -o yaml --export $R > ${APP_BACKUP_DIR}/${R}.yaml
done

# Get all projects
echo -e "[$(date +%x-%X)] Starting OpenShift projects backup"
PROJECTS=$(oc get projects -o name | cut -d'/' -f2)

# Get all namespaced K8s/OpenShift resource types
RESOURCES=$(oc api-resources -o name --namespaced=true --verbs=get list | cut -d'.' -f1)

# Backup all projects into designated folder
for P in $PROJECTS
do
    echo -e "[$(date +%x-%X)] Starting backup of ${P} project"
    mkdir -p "${APP_BACKUP_DIR}/${P}/"
    oc project $p > /dev/null 2>&1
    oc get -o yaml --export all > ${APP_BACKUP_DIR}/${P}/${P}.yaml
    for R in $RESOURCES
    do
        echo -e "[$(date +%x-%X)] OpenShift project ${P} resource ${R} backup"
        oc get -o yaml --export $R > ${APP_BACKUP_DIR}/${P}/${P}_${R}.yaml
    done
done

echo -e "[$(date +%x-%X)] Delete old backups"

# Delete backups older than 7 days
find /opt/backup/applications/* -ctime +6 -exec rm -rf {} \;
find /opt/backup/system/* -ctime +6 -exec rm -rf {} \;

# Log end of backup
echo -e "[$(date +%x-%X)] Backup finished"