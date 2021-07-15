#aws ec2 describe-snapshots --owner self --output json | jq '.Snapshots[] | select(.StartTime < "'$(date --date='-1 month' '+%Y-%m-%d')'
prod=$(date -d "-7 days" +%Y-%m-%d)
dev=$(date -d "-3 days" +%Y-%m-%d)
#aws ec2 describe-snapshots --filters "Name=tag:Deleteon,Values=$futuredt01" "Name=status,Values=completed"  --query "Snapshots[?(StartTime<='$futuredt02')].[SnapshotId]" --output table
#aws ec2 describe-snapshots --owner self --output json | jq '.Snapshots[] | select(.StartTime < "'$(date --date='-1 month' '+%Y-%m-%d')'


#snapshots_to_delete=$(aws ec2 describe-snapshots  --query 'Snapshots[?StartTime<=`'${dev}'`].SnapshotId' --filters "Name=tag:Database,Values=Oracle" --output text)
beautifying=$(aws ec2 describe-snapshots  --query "Snapshots[?(StartTime<='$dev')].[SnapshotId,Description,StartTime,VolumeId,State]"  --filters "Name=tag:Database,Values=Oracle" --output table)
#beautifying=$(aws ec2 describe-snapshots  --query "Snapshots[?(StartTime<='$dev')].[SnapshotId]"  --filters "Name=tag:Database,Values=Oracle" --output text| wc -l)
echo -e "Number of  snapshots to deleted: $beautifying"

#snap_delete=$(aws ec2 describe-snapshots  --query "Snapshots[?(StartTime<='$dev')].[SnapshotId]"  --filters "Name=tag:Database,Values=Oracle" --output text)
# actual deletion
for snapshot in $snap_delete; do
          aws ec2 delete-snapshot --snapshot-id $snapshot
done
