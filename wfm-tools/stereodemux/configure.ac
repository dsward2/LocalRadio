AC_PREREQ([2.69])
AC_INIT([stereodemux], [0.1-SNAPSHOT], [oona@kapsi.fi], [stereodemux],
        [https://github.com/windytan/wfm-tools])
AM_INIT_AUTOMAKE([1.10 -Wall -Werror foreign subdir-objects])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([
 Makefile
])

AC_ARG_WITH([macports],
            [AS_HELP_STRING([--without-macports],
               [disable check for MacPorts directories when compiling])])

LIQUID=
  AC_CHECK_LIB([liquid], [symtrack_cccf_create],
    [AC_SUBST([LIQUID], ["-lliquid"])
     AC_DEFINE([HAVE_LIQUID], [1],
               [Define if you have liquid])
    ],
    [AC_MSG_FAILURE(
       [Could not find liquid-dsp])])

MACPORTS_LD=
AS_IF([test "x$with_macports" != xno],
  [AC_CHECK_FILE(/opt/local/lib,
    [AC_SUBST([MACPORTS_LD], ["-L/opt/local/lib"])])])

MACPORTS_CF=
AS_IF([test "x$with_macports" != xno],
  [AC_CHECK_FILE(/opt/local/lib,
    [AC_SUBST([MACPORTS_CF], ["-I/opt/local/include"])])])

AC_CHECK_LIB([sndfile], [main],
  [AC_SUBST([SNDFILE], ["-lsndfile"])
   AC_DEFINE([HAVE_SNDFILE], [1],
             [Define if you have libsndfile])
  ],
  [AC_MSG_FAILURE(
     [Could not find libsndfile])])

AC_PROG_CXX
AC_PROG_RANLIB
AC_LANG([C++])

AC_OUTPUT
