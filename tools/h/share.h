/*
 *  share.h     Define file sharing modes for sopen()
 *
 * =========================================================================
 *
 *                          Open Watcom Project
 *
 *    Copyright (c) 2002-2010 Open Watcom Contributors. All Rights Reserved.
 *    Portions Copyright (c) 1983-2002 Sybase, Inc. All Rights Reserved.
 *
 *    This file is automatically generated. Do not edit directly.
 *
 * =========================================================================
 */
#ifndef _SHARE_H_INCLUDED
#define _SHARE_H_INCLUDED

#ifndef _ENABLE_AUTODEPEND
 #pragma read_only_file;
#endif

#define _SH_COMPAT  0x00    /* compatibility mode   */
#define _SH_DENYRW  0x10    /* deny read/write mode */
#define _SH_DENYWR  0x20    /* deny write mode      */
#define _SH_DENYRD  0x30    /* deny read mode       */
#define _SH_DENYNO  0x40    /* deny none mode       */

#if !defined(NO_EXT_KEYS) /* extensions enabled */
#define SH_COMPAT   _SH_COMPAT
#define SH_DENYRW   _SH_DENYRW
#define SH_DENYWR   _SH_DENYWR
#define SH_DENYRD   _SH_DENYRD
#define SH_DENYNO   _SH_DENYNO
#endif /* extensions enabled */

#endif
