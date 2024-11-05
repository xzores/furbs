/*
 * Copyright (c) 2005-2009 Jaroslav Gresula
 *
 * Distributed under the MIT license (See accompanying file
 * LICENSE.txt or copy at http://jagpdf.org/LICENSE.txt)
 *
 */
#ifndef VERSION_JG2316_H__
#define VERSION_JG2316_H__

#include <jagpdf/detail/types.h>

#define jag_this_version_major 1u
#define jag_this_version_minor 4u
#define jag_this_version_patch 0u

#define jag_this_version                                        \
    (jag_this_version_major << 16)                              \
    | (jag_this_version_minor << 8)                             \
    | jag_this_version_patch



#ifdef __cplusplus
namespace jag {
namespace pdf
{
  const UInt this_version_major = jag_this_version_major;
  const UInt this_version_minor = jag_this_version_minor;
  const UInt this_version_patch = jag_this_version_patch;
  const UInt this_version = jag_this_version;
}}
#endif

#endif
/** EOF @file */
