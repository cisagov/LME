#!/bin/bash
#!/bin/bash
LME_DIR=/opt/lme/
IFS=$'\n'
Dashboards="$(ls -1 ${LME_DIR}Chapter\ 4\ Files/dashboards/*.ndjson)"
echo $Dashboards

# -------------- cron job automatic logger code START --------------

# See my ans: https://stackoverflow.com/a/60157372/4561887
FULL_PATH_TO_SCRIPT="$(realpath "${BASH_SOURCE[-1]}")"
SCRIPT_DIRECTORY="$(dirname "$FULL_PATH_TO_SCRIPT")"
SCRIPT_FILENAME="$(basename "$FULL_PATH_TO_SCRIPT")"

LOG_DIR=/var/log/cron_logs
mkdir -p $LOG_DIR
DATE="$(date '+%Y-%m-%d-%H:%M:%S')"

# Automatically log the output of this script to a file!
begin_logging() {

    # Redirect all future prints in this script from this call-point forward to
    # both the screen and a log file!
    #
    # This is about as magic as it gets! This line uses `exec` + bash "process
    # substitution" to redirect all future print statements in this script
    # after this line from `stdout` to the `tee` command used below, instead.
    # This way, they get printed to the screen *and* to the specified log file
    # here! The `2>&1` part redirects `stderr` to `stdout` as well, so that
    # `stderr` output gets logged into the file too.
    # See:
    # 1. *****+++ https://stackoverflow.com/a/49514467/4561887 -
    #    shows `exec > >(tee $LOG_FILE) 2>&1`
    # 1. https://superuser.com/a/569315/425838 - shows `exec &>>` (similar)
    exec > >(tee -a "${LOG_DIR}/${SCRIPT_FILENAME}"+$DATE".log") 2>&1

    echo ""
    echo "====================================================================="
    echo "Running cronjob \"$FULL_PATH_TO_SCRIPT\""
    echo "on $DATE"
    echo "Cmd:  $0 $@"
    echo "====================================================================="
}


main() {
 /opt/lme/Chapter\ 3\ Files/deploy.sh upgrade
}

# ------------------------------------------------------------------------------
# main program entry point
# ------------------------------------------------------------------------------
if [ "$1" == "log" ];
then
  begin_logging "$@"
fi
time main "$@"
