#!/bin/bash
# Copyright (c) 2010 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 2 (GPLv2). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
#
# Red Hat trademarks are not licensed under GPLv2. No permission is
# granted to use or replicate Red Hat trademarks that are incorporated
# in this software or its documentation.
#
# written by whayutin@redhat.com
# modified by kbidarka@redhat.com for RHEL 6
#             mkovacik@redhat.com

FAILURES=0
MEM_HWP=0
BUGZILLA=1
POSTREBOOT=1

# try to pushd to a `valid' source tree
[ -z $BASEDIR ] && BASEDIR=/root/valid/src
[ -d $BASEDIR ] || BASEDIR=$PWD
pushd $BASEDIR > /dev/null
source testlib.sh
_testlib_init

function build_python_bugzilla() {
	# get python-bugzilla from fedorahosted
	if [ -z ${RHELV%5.*} ]; then
	    #rpm -i http://dl.fedoraproject.org/pub/epel/5/i386/python-bugzilla-0.7.0-1.el5.noarch.rpm
	    #perl -pi -e "s/except (.*) as (.*):/except \$1, \$2:/g" /usr/lib/python2.4/site-packages/bugzilla/util.py
        ln -s /bin/true /usr/bin/bugzilla
	else
	    rpm -i http://dl.fedoraproject.org/pub/epel/6/i386/python-bugzilla-0.7.0-1.el6.noarch.rpm
	fi
}

#set -x
echo =====`basename $0; date`===== | $DLOG
function list_tests(){
	# return the list of defined tests
	declare -F | cut -d\  -f3,3  | grep "^test_.*"
}

function _sa_east_1_hosts(){
	# a quick hack to avoid DNS resolve errors in yum...
		cat <<-__SA_EAST_1_HOSTS >>/etc/hosts
		# DNS workaround `date`
		177.71.186.7    rhui2.sa-east-1.aws.ce.redhat.com
		177.71.186.16   rhui2-cds01.sa-east-1.aws.ce.redhat.com
		177.71.186.17   rhui2-cds02.sa-east-1.aws.ce.redhat.com
__SA_EAST_1_HOSTS
}

function filter_tests(){
	# produces the list of tests to execute
	# args:
	# 	list of skip expressions to use with egrep
	# return:
	# 	list of passing function names

	# @ is an identity element; hopefully, it won't ever match ;)
	local skip="@,${@}"
	skip="${skip%,}" # cut off trailing spaces; takes care of empty $@, too
	# convert the coma or space separated list to an expression of elements
	# separated by `|'
	shopt -s extglob
	skip="${skip//*([[:space:]])[,[:space:]]*([[:space:]])/|}"
	shopt -u extglob
	# figure out all test functions passing the skip list
	list_tests | egrep -v "${skip}"
}

function usage()
{
           echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
	   echo "Please use all options"
	   echo ""
           echo " This script will run through some basic sanity tests for a Red Hat Enterprise Linux image "
           echo " A valid Red Hat bugzilla username and password will be required at the end of the script "
           echo " http://bugzilla.redhat.com/ "
           echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
           echo ""
           echo "Available options are:"
           echo "--imageID=          :: Please provide a unique id for the image"
           echo "--RHEL=             :: Please specify the correct FULL rhel version eg: --RHEL=5.7 or --RHEL=6.1"
           echo "--full-yum-suite=   :: Please input the value  "yes" OR "no""          
	   echo "--skip-questions=   :: Please input the value  "yes" or "no""
	   echo "--bugzilla-username :: Please specify your bugzilla username@email.com"
	   echo "--bugzilla-password :: Please specify your bugzilla password"
	   echo "--bugzilla-num      :: If a bug has already been opened you can specify the number here "
	   echo "--memory	     :: Minium total memory the system *should* have available"
	   echo "--public-dns	     :: The Public-DNS Host name of the machine"
	   echo "--ami-id	     :: The AMI ID"
	   echo "--arch-id	     :: The Architecture i386 or x86_64 for the launched instance"
	   echo "--skip-list	 :: A list of coma-separated expressions specifying test names
	                            to skip. A skip-list might contain:
                                    test_repos,test_yum_full_test,test_IPv6"
	   echo "--list-tests    :: list available tests"
}


### MAIN
##  Main
#   main

#cli
#set -x
for i in $*
 do
 case $i in
      --imageID=*)
         IMAGEID="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
         ;;
      --RHEL=*)
         RHELV="`echo $i | sed 's/[-A-Z]*=//'`"
         ;;
      --full-yum-suite=*)
          yum_test="`echo $i | sed 's/[-a-zA-Z]*=//'`"
          if [ "$yum_test" == "yes" ] || [ "$yum_test" == "no" ]; then
            :
          else
	    usage
            exit 1
          fi
          ;;
      --skip-questions=*)
	  QUESTIONS="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --bugzilla-username=*)
	  BUG_USERNAME="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --bugzilla-password=*)
	  BUG_PASSWORD="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --bugzilla-num=*)
	  BUG_NUM="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --memory=*)
	  MEM_HWP="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --public-dns=*)
	  PUB_DNS="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --ami-id=*)
	  AMI_ID="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --arch-id=*)
	  ARCH_ID="`echo $i | sed 's/[-a-zA-Z0-9]*=//'`"
	  ;;
      --skip-list=*)
	  SKIP_LIST="${i#*=}"
	  ;;
      --list-tests)
	  list_tests
	  exit 0
	  ;;
      --staging)
	 _testlib_init_staging
          ;;
      --no-bugzilla)
         BUGZILLA=0
	 ;;
      --no-postreboot)
        POSTREBOOT=0
	;;

        *)
         # unknown option
	   usage
           exit 1
           ;;
 esac
done
# initialize testlib
#_testlib_init
#_sa_east_1_hosts


if [[ -z $IMAGEID ]] || [[ -z $RHELV ]] ||  [[ -z $yum_test ]] || [[ -z $MEM_HWP ]]; then
 usage
 exit 1
fi

if [ ${BUGZILLA:-1} -gt 0 ] ; then
	if [[ -z $BUG_USERNAME ]] || [[ -z $BUG_PASSWORD ]] ; then
		usage
		exit 1
	fi
fi

### DONT REMOVE OR COMMENT OUT ###
if [ ${BUGZILLA} -gt 0 ] ; then
	## provide python-bugzilla's bugzilla command
	build_python_bugzilla || exit $?
	## open bugzilla
	echo "opening a bugzilla for logging purposes"
	open_bugzilla
fi
##################################

echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
echo " This script will run through some basic sanity tests for a Red Hat Enterprise Linux image "
echo " A valid Red Hat bugzilla username and password will be required at the end of the script "
echo " http://bugzilla.redhat.com/ "
echo ""
echo "***************** DETAILED RESULTS LOGGED TO validate.log  ********************************"
echo " !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! " 
echo "" 
echo ""
test_fetch_host_details
test_rhel_version
echo ""
if [ $QUESTIONS == "no" ];then
 userInput_CloudProvider
 userInput_Filesystem
 userInput_Errata_Notification
 userInput_Availability
fi
echo "##### START TESTS #####"
echo ""
# skip-list might contain
# 	installTestKernel,test_repos,test_yum_full_test,test_IPv6,

for f in $( filter_tests $SKIP_LIST ) ; do
	$f
done

### DONT REMOVE OR COMMENT OUT ###
show_failures
if [ ${BUGZILLA} -gt 0 ] ; then
	open_bugzilla
	bugzilla_comments
fi
sed -i 's/default=1/default=0/' /boot/grub/grub.conf

if [ ${POSTREBOOT} -eq 1 ] ; then
	setup_rc.local 
	#sos_report
	echo "REBOOTING"
	sleep 1
	echo "REBOOTING"
	sleep 1
	echo "REBOOTING"
	reboot
else
	im_exit
fi
##################################
