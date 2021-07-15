

# ==========================================================================================================
#  name: Oracle_Database_Backup_Automation
#  date: 03-10-2021
#  ver: 1.0.0
#  Author: [Bijith Nair] - bijith.nair@hitachivantara.com
#  purpose: // Script to Automate oracle Database Backup Along with AWS Snapshot based backups - Crash Consistent //
# ==========================================================================================================


# Exit Codes:
# 1. 0   : Success
# 2. 126 : Execution Failed, Unable to set Environment variables. *Reference Location: [/u01/app/oraglobp/GLOBPRD/db/tech_st/12.1.0/GLOBPRD_globprd.env]
# 3. 130 : Command Not Found
# 3. 512 : SnapshotCreationPerVolumeRateExceeded : Backup times overlap, The Snapshot based backup is on hold and will be released once AWS backup Services release the lock

# Variables

instancename="glbusalapt001"
archmount="glbusalapt001-Data-u02"
duration=`date -u`
datefmt=`date +"Time: %r, Date: %m-%d-%Y"`
random=`shuf -i1-10000 -n1`
TTIME=`date +%m%d%Y%H%M`
LOG=/backup/GLOBDEV/trace
GLOBENV=/u01/app/oraglobd/GLOBDEV/19.3.0/cglobdev_glbusalapt001.env
futuredt01=$(date -d "+7 days" +%Y-%m-%d)
futuredt02=$(date -d "+1 days" +%Y-%m-%d)
ebsvol=`aws ec2 describe-volumes --query 'Volumes[*].[VolumeId]' --output text --filters Name=attachment.instance-id,Values=$insid`

# To keep a Track of the task, Assigning Task ID to each execution

echo -e "- Task ID: [$random]"

# Putting Database in Begin Backup Mode

#echo -e "- Database Version: Oracle DB 12C "
echo -e "- Performing Prerequisites Checks"

if [ -e ${GLOBENV} ]
then
echo -e "- Initiating Begin Backup Mode for $instancename"
. ${GLOBENV}


sqlplus -S /nolog << EOF
conn / as sysdba
spool ${LOG}/begin_backup_{$TTIME}.log
alter system switch logfile;
alter system switch logfile;
alter system switch logfile;
alter system checkpoint;
alter database backup controlfile to trace as '${LOG}/gloprd_control_file_${TTIME}.sql';
alter database begin backup;
alter system switch logfile;
alter system switch logfile;
alter system switch logfile;
exit;
EOF
else
echo -e  "- [Failed] : Exit Code - 126" && exit
fi
sleep 2
echo -e "- Begin Backup Mode: [Enabled] for [$instancename]"
echo -e "- Fetching Instance ID's.."
sleep 2
echo -e "- Job Started"

for insid in `aws ec2 describe-instances --filters "Name=tag:Name,Values=$instancename" --query 'Reservations[*].Instances[*].{Instance:InstanceId}' --output text`
do
echo -e "- Initiating Snapshot based backup for Instance : [$insid]"
aws ec2 create-snapshots --instance-specification InstanceId=$insid --tag-specifications 'ResourceType=snapshot,Tags=[{Key="Database",Value="Oracle"},{Key="Deleteon",Value='${futuredt01}'}]' --copy-tags-from-source volume --description "This is snapshot of a volume from my-instance" |  grep SnapshotId | awk '{print $2}' | cut -d "," -f1 | sed -e 's/^"//' -e 's/"$//' | xargs aws ec2 wait snapshot-completed --snapshot-ids
done


for snapid in `aws ec2 describe-snapshots --filters "Name=tag:Deleteon,Values=$futuredt01" "Name=status,Values=pending,completed"  --query "Snapshots[?(StartTime<='$futuredt02')].[SnapshotId]" --output text`

        do
echo -e "- Snapshot status [In-Progress] : [$snapid], Taking longer time than expected. Waiting!!!"
until aws ec2 wait snapshot-completed --snapshot-ids $snapid
do
            printf "\rsnapshot progress: %s" $progress;
                        sleep 10
                            progress=$(aws ec2 describe-snapshots --snapshot-ids $snapid --query "Snapshots[*].Progress" --output text)
                    done
echo "- Snapshot status [Completed]  : [$snapid]"
done

echo -e "- initiating End Backup Mode for aw2glootest"

if [ -e ${GLOBENV} ]
then
. ${GLOBENV}
sqlplus -S /nolog << EOF
conn / as sysdba
spool ${LOG}/end_backup_{$TTIME}.log
alter database end backup;
ALTER SYSTEM ARCHIVE LOG CURRENT;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM SWITCH LOGFILE;
exit;
EOF
echo -e "- Begin Backup Mode: [Disabled] for [$instancename]"
else
echo -e  "- [Error] : End Backup Failed with Exit Code - 126"
fi

echo -e "- Initiating Archive logs Backup"

for archlog in `aws ec2 describe-volumes --filters "Name=tag:Name,Values=$archmount"  --query "Volumes[*].{ID:VolumeId}" --output text`
do

aws ec2 create-snapshot --description "This is snapshot of a volume from my-instance" --tag-specifications 'ResourceType=snapshot,Tags=[{Key="Name",Value='${archmount}'},{Key="Database",Value="Oracle"},{Key="Archivelog",Value="Yes"},{Key="Deleteon",Value='${futuredt01}'}]' --volume-id $archlog |  grep SnapshotId | awk '{print $2}' | cut -d "," -f1 | sed -e 's/^"//' -e 's/"$//' | xargs aws ec2 wait snapshot-completed --snapshot-ids

done

for snapid in `aws ec2 describe-snapshots --filters "Name=tag:Deleteon,Values=$futuredt01" "Name=tag:Archivelog,Values=Yes" "Name=status,Values=pending,completed"  --query "Snapshots[?(StartTime<='$futuredt02')].[SnapshotId]" --output text`

        do
echo -e "- Snapshot status [In-Progress] : [$snapid], Taking longer time than expected. Waiting!!!"
until aws ec2 wait snapshot-completed --snapshot-ids $snapid 2>/dev/null
do
            printf "\rsnapshot progress: %s" $progress;
                        sleep 10
                            progress=$(aws ec2 describe-snapshots --snapshot-ids $snapid --query "Snapshots[*].Progress" --output text)
                    done
echo "- Snapshot status [Completed]  : [$snapid]"
done



# Updating the Logs with Job Completion Exit Code

echo -e  "- Job Completed"
