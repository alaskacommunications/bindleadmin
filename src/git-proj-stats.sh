#!/bin/sh
#
#   Bindle Binaries Tools
#   Copyright (C) 2011 Bindle Binaries <syzdek@bindlebinaries.com>.
#
#   @BINDLE_BINARIES_BSD_LICENSE_START@
#
#   Redistribution and use in source and binary forms, with or without
#   modification, are permitted provided that the following conditions are
#   met:
#
#      * Redistributions of source code must retain the above copyright
#        notice, this list of conditions and the following disclaimer.
#      * Redistributions in binary form must reproduce the above copyright
#        notice, this list of conditions and the following disclaimer in the
#        documentation and/or other materials provided with the distribution.
#      * Neither the name of Bindle Binaries nor the
#        names of its contributors may be used to endorse or promote products
#        derived from this software without specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
#   IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
#   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
#   PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL BINDLE BINARIES BE LIABLE FOR
#   ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#   DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
#   SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
#   CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#   LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
#   OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#   SUCH DAMAGE.
#
#   @BINDLE_BINARIES_BSD_LICENSE_END@
#
#   git-proj-stats.sh - script for generating development stats on active projects
#

REPODIR=/pub/scm
SRCDIR=/pub/src

TEMPLATE=/tmp/mail-project-stats.$$
DATE=`date +%Y-%m-%d`
TIMELIMIT=30
TIMEINTERVALS="1 7 14 30 90 365"


# tests configuration
if test ! -d ${REPODIR};then
   echo "${0}: ${REPODIR}: repository prefix does not exist" 1>&2
   exit 1
fi
if test ! -d ${SRCDIR};then
   echo "${0}: ${SRCDIR}: source prefix does not exist" 1>&2
   exit 1
fi


echo "Generating list of repositories..."
for DOMAIN in `ls ${REPODIR}`;do
   if test -d ${REPODIR}/${DOMAIN};then
      for REPO in `ls -d ${REPODIR}/${DOMAIN}/*.git 2> /dev/null`;do
         if test -d ${REPO};then
            REPOLIST="${REPOLIST} ${REPO}"
         fi
      done
   fi
done


echo "creating directory structure..."
for REPO in ${REPOLIST};do
   SRC=`echo ${REPO} |sed -e "s,${REPODIR},${SRCDIR},g"`
   DOMAINDIR=`dirname ${SRC}`
   PROJNAME=`basename ${SRC} |sed -e 's/.git$//g'`
   PROJDIR="${DOMAINDIR}/${PROJNAME}"
   SRCLIST="${SRCLIST} ${PROJDIR}"
   if test ! -d ${PROJDIR};then
      echo "Creating ${DOMAINDIR}/${PROJNAME}..."
      mkdir -p ${DOMAINDIR} || exit 1
      cd ${DOMAINDIR} || exit 1
      git clone ${REPO} || exit 1
      cd ${PROJDIR} || exit 1
      git branch master origin/master > /dev/null 2>&1
      git branch next   origin/next   > /dev/null 2>&1
      git branch pu     origin/pu     > /dev/null 2>&1
   fi
   cp ${REPO}/description ${PROJDIR}/.git/description
   cd ${PROJDIR} > /dev/null || exit 1
   git checkout pu > /dev/null 2>&1
   git pull > /dev/null || exit 1
done


echo "generating list of active projects..."
for PROJDIR in ${SRCLIST};do
   cd ${PROJDIR};
   DATA=`git diff --stat $(git rev-list -n1 --before="${TIMELIMIT} day ago" pu 2> /dev/null) 2> /dev/null`
   if test "x${DATA}" != "x";then
      STATLIST="${STATLIST} ${PROJDIR}"
   fi
done


cat << EOF > ${TEMPLATE}
To: @EMAIL_ADDRESS@
From: "David M. Syzdek" <syzdek@bindlebinaries.com>
Subject: Bindle Binaries Project Activity (${DATE})
Content-Type: text/html; charset=ISO-8859-1

EOF


echo "<div style='color:#660066'><h3>Active Projects (Last ${TIMELIMIT} days)</h3></div>"   >> ${TEMPLATE}
for PROJDIR in ${STATLIST};do
   PROJNAME=`basename ${PROJDIR}`
   PROJCLIENT=`dirname ${PROJDIR}`
   PROJCLIENT=`basename ${PROJCLIENT}`
   if test -d ${PROJDIR};then
      echo -n "<p>"                                              >> ${TEMPLATE}
      echo "<b>${PROJNAME}</b>"                                  >> ${TEMPLATE}
      echo "<i>(${PROJCLIENT})</i><br/>"                         >> ${TEMPLATE}
      if test -f ${PROJDIR}/.git/description;then
         echo -n "<i>"                                           >> ${TEMPLATE}
         cat ${PROJDIR}/.git/description                         >> ${TEMPLATE}
         echo "</i>"                                             >> ${TEMPLATE}
      fi
     echo "</p>"                                                 >> ${TEMPLATE}
   fi
done


echo '<div style="color:#660066"><h3>Project Statistics</h3></div>'   >> ${TEMPLATE}
for REPO in ${STATLIST};do
   PROJNAME=`basename ${REPO}`
   if test -d ${REPO};then
      echo "running git diff on ${REPO}..."
      cd ${REPO}
      echo -n "<p>"                                             >> ${TEMPLATE}
      echo "<b>${PROJNAME}</b>"                                 >> ${TEMPLATE}

      for NUM in ${TIMEINTERVALS};do
         STAT=`git diff --stat $(git rev-list -n1 --before="${NUM} day ago" pu) |grep 'files changed, '`
         if test "x${STAT}" != "x";then
            echo "<br/>Changes to pu branch in last  ${NUM} day(s): ${STAT}" >> ${TEMPLATE}
         fi
      done

      echo "</p>"                                                >> ${TEMPLATE}
   fi
done


echo "running ohcount..."
echo '<div style="color:#660066"><h3>Project Summaries</h3></div>'   >> ${TEMPLATE}
for REPO in ${STATLIST};do
   PROJNAME=`basename ${REPO}`
   if test -d ${REPO};then
      echo "running ohcount on ${REPO}..."
      cd ${REPO}
      echo -n "<p>"                                              >> ${TEMPLATE}
      echo "<b>${PROJNAME}</b><br/>"                             >> ${TEMPLATE}
      echo -n "<pre>"                                            >> ${TEMPLATE}
      /usr/local/bin/ohcount ${REPO} |egrep -v '^$|Examining|Ohloh'    >> ${TEMPLATE}
      echo -n "</pre>"                                           >> ${TEMPLATE}
      echo "</p>"                                                >> ${TEMPLATE}
   fi
done


cat << EOF >> ${TEMPLATE}
<div style='color:#660066'><h3>Help</h3></div>
<p>
A project's repository contains multiple branches which are used to organize the
development process.  Bindle Binaries uses the following standards for branch
information:
<pre>
      master - Current release of packages.
      next   - changes staged for next release
      pu     - proposed updates for next release
      xx/yy+ - branch for testing new changes before merging to 'pu' branch
</pre>
Active development occurrs either directly or indirectly on the 'pu' branch.  Once
modifications are considered stable, they are merged from the 'pu' branch into the
'next' branch. The modifications are not merged into the 'master' branch until a
new public release (aka version) of the project is published. As such, information
in this message is generated from the 'pu' branch of a project rather than the
'next' or 'master' branches which are much less frequently updated.
<p>
<b><i>The information in this message was generated using Ohcount and Git.</i></b>

EOF


SENTRESULTS=NO
for ADDR in $@;do
   echo "sending results to ${ADDR}..."
   sed -e "s/[@]EMAIL_ADDRESS[@]/${ADDR}/g" ${TEMPLATE} |sendmail -t ${ADDR}
   SENTRESULTS=YES
done

if test "x${SENTRESULTS}" == "xNO";then
   cat ${TEMPLATE}
fi

rm -f /tmp/mail-project-stats.*

# end of script
