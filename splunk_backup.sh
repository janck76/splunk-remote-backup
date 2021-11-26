#!/usr/bin/bash

declare -a hosts=("devsplunk0" "sh0" "splunkcm.internbank.no" "licensemaster" "hf0" "hf1")

LOGDIR="/opt/backup/remote/log"

function now() {
   date +%F' '%T
}

function log() {
   LOG="$LOGDIR/splunk_backup.log"
   LEVEL=$1; shift
   SRC=$1; shift
   echo "Timestamp=\"$(now)\" Level=\"$LEVEL\" SourceHost=\"$SRC\" Message=\"$*\"" >>$LOG
}

function backup() {
  host=$1

  echo "Backing up $host"
  log "INFO" $host "Backing up $host"
  mount=/home/splunk/mount/$host
  target=/opt/backup/remote/$host
  if [ ! -d $mount ]; then
    mkdir $mount
  fi

  src="/opt/backup"
  if [[ "$host" == "devsplunk0" ]]; then
    src="/opt/splunkdata/cold/backup"
  fi

  timeout 5 sshfs -o default_permissions splunk@$host:$src $mount &>/tmp/out.txt
  if [ $? -gt 0 ]; then
    log "ERROR" $host "sshfs failed"
    while read p; do
      log "ERROR" $host "$p"
    done </tmp/out.txt
    return 1
  fi

  source_name="$(ls -1tr $mount | grep splunk_| tail -1)"
  source_path="$mount/$source_name"
  target_name=$source_name
  if [ ! -d $source ]; then
    log "ERROR" $host "$source does not exist"
    umount $mount
    return 1
  fi

  if [ ! -d $target ]; then
    mkdir $target
  fi

  cd $target
  if [ $? -gt 0 ]; then
    log "ERROR" $host "cd $target failed"
    umount $mount
    return 1
  fi

  if [ ! -d "$target/$target_name/.git" ]; then
    git clone $source_path
    if [ $? -gt 0 ]; then
      log "ERROR" $host "git clone $source failed"
      umount $mount
      return 1
    fi
  else
    cd $target_name
    git pull &> /tmp/out.txt
    if [ $? -gt 0 ]; then
      log "ERROR" $host "git pull failed in $target/$target_name"
      while read p; do
        log "ERROR" $host "$p"
      done </tmp/out.txt
      umount $mount
      return 1
    fi
  fi

  log "INFO" $host "Successfully backed up $target/$target_name"

  umount $mount
}

for i in "${hosts[@]}"
do
  backup $i
done
