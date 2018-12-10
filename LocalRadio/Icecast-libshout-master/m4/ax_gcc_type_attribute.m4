#
# SYNOPSIS
#
#   AX_GCC_TYPE_ATTRIBUTE(ATTRIBUTE)
#
# DESCRIPTION
#
#   This macro checks if the compiler supports one of GCC's type
#   attributes; many other compilers also provide type attributes with
#   the same syntax. Compiler warnings are used to detect supported
#   attributes as unsupported ones are ignored by default so quieting
#   warnings when using this macro will yield false positives.
#
#   The ATTRIBUTE parameter holds the name of the attribute to be checked.
#
#   If ATTRIBUTE is supported define HAVE_TYPE_ATTRIBUTE_<ATTRIBUTE>.
#
#   The macro caches its result in the ax_cv_have_type_attribute_<attribute>
#   variable.
#
#   The macro currently supports the following type attributes:
#
#    transparent_union
#
#   Unsupported type attributes will cause an error.
#
# LICENSE
#
#   AX_GCC_TYPE_ATTRIBUTE is nearly identical to the AX_GCC_VAR_ATTRIBUTE
#   macro, by Gabriele Svelto:
#
#   Copyright (c) 2013 Gabriele Svelto <gabriele.svelto@gmail.com>
#
#   Copying and distribution of this file, with or without modification, are
#   permitted in any medium without royalty provided the copyright notice
#   and this notice are preserved.  This file is offered as-is, without any
#   warranty.
#
#   Modified by Marvin Scholz <epirat07@gmail.com>

#serial 5

AC_DEFUN([AX_GCC_TYPE_ATTRIBUTE], [
    AS_VAR_PUSHDEF([ac_var], [ax_cv_have_type_attribute_$1])

    AC_CACHE_CHECK([for __attribute__(($1))], [ac_var], [
        AC_LINK_IFELSE([AC_LANG_PROGRAM([
            m4_case([$1],
                [transparent_union], [
                    union __attribute__((__$1__)) { void *vp; } tu;
                ],
                [
                    m4_fatal([Unsupported attribute $1])
                ]
            )], [])
            ],
            dnl GCC doesn't exit with an error if an unknown attribute is
            dnl provided but only outputs a warning, so accept the attribute
            dnl only if no warning were issued.
            [AS_IF([test -s conftest.err],
                [AS_VAR_SET([ac_var], [no])],
                [AS_VAR_SET([ac_var], [yes])])],
            [AS_VAR_SET([ac_var], [no])])
    ])

    AS_IF([test yes = AS_VAR_GET([ac_var])],
        [AC_DEFINE_UNQUOTED(AS_TR_CPP(HAVE_TYPE_ATTRIBUTE_$1), 1,
            [Define to 1 if the system has the `$1' type attribute])], [])

    AS_VAR_POPDEF([ac_var])
])
