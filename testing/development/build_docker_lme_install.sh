#!/usr/bin/env bash
<<<<<<< HEAD

# Parse command line arguments
while getopts ":b:v:" opt; do
  case $opt in
    b)
      if [ -n "$version" ]; then
        echo "Cannot use both -b and -v options simultaneously" >&2
        exit 1
      fi
      branch="$OPTARG"
      ;;
    v)
      if [ -n "$branch" ]; then
        echo "Cannot use both -b and -v options simultaneously" >&2
        exit 1
      fi
      version="$OPTARG"
      ;;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1;;
  esac
done

cd testing/configure || exit

sudo ./linux_update_system.sh

# Pass the branch or version argument to linux_install_lme.sh
if [ -n "$branch" ]; then
  sudo ./linux_install_lme.sh -b "$branch"
elif [ -n "$version" ]; then
  sudo ./linux_install_lme.sh -v "$version"
else
  sudo ./linux_install_lme.sh
fi

. lib/functions.sh
extract_credentials
echo $elastic

cd ../tests/ || exit

python3 -m venv /home/admin.ackbar/venv_test
. /home/admin.ackbar/venv_test/bin/activate
pip install -r requirements.txt
sudo chown admin.ackbar:admin.ackbar /home/admin.ackbar/venv_test -R
=======
cd testing/configure || exit
sudo ./linux_update_system.sh
sudo ./linux_install_lme.sh -b cbaxley-168-python_tests
. lib/functions.sh
extract_credentials
cd ../tests/ || exit
python3 -m venv ~/venv_test
. ~/venv_test/bin/activate
pip install -r requirements.txt
#pytest api_tests/linux_only/
>>>>>>> origin/release-1.4.0
