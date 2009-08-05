module libiconv;

/* Copyright (C) 1999-2003 Free Software Foundation, Inc.
   See http://www.gnu.org/software/libiconv/

   The GNU LIBICONV Library is free software; you can redistribute it
   and/or modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   The GNU LIBICONV Library is distributed in the hope that it will be
   useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with the GNU LIBICONV Library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation, Inc., 59 Temple Place -
   Suite 330, Boston, MA 02111-1307, USA.  */

private {
 // import std.loader;
  import std.c.stdlib;
}

/// converter datatype
typedef void *iconv_t;

version (Win32) {

  // on Win32 dynamically load iconv.dll and bind function pointers
  // Users must put iconv.dll from 
  //  http://prdownloads.sourceforge.net/gettext/libiconv-1.9.1.bin.woe32.zip?download
  // on their path (eg, the same directory as the main executable)

  /// allocate a converter between charsets fromcode and tocode
  extern (C) iconv_t (*iconv_open) (char *tocode, char *fromcode);

  /// convert inbuf to outbuf and set inbytesleft to unused input and
  /// outbuf to unused output and return number of non-reversable 
  /// conversions or -1 on error.
  extern (C) size_t (*iconv) (iconv_t cd, void **inbuf,
			      size_t *inbytesleft,
			      void **outbuf,
			      size_t *outbytesleft);

  /// close converter
  extern (C) int (*iconv_close) (iconv_t cd);

  static this() {
    ExeModule_Init();
    HXModule mod = ExeModule_Load("iconv");
    if (mod is null)
      throw new Error("Cannot load iconv dynamic library");
    iconv_open = cast(typeof(iconv_open))ExeModule_GetSymbol(mod,"libiconv_open");
    iconv_close = cast(typeof(iconv_close))ExeModule_GetSymbol(mod,"libiconv_close");
    iconv = cast(typeof(iconv))ExeModule_GetSymbol(mod,"libiconv");
  }

} else version (darwin) { 

  // On Mac OS X, link with -liconv (/usr/lib/libiconv.dylib)
  typedef void *libiconv_t;

  /// allocate a converter between charsets fromcode and tocode
  extern (C) libiconv_t libiconv_open (char *tocode, char *fromcode);
  iconv_t iconv_open (char *tocode, char *fromcode)
  { return cast(iconv_t) libiconv_open(tocode, fromcode); }

  /// convert inbuf to outbuf and set inbytesleft to unused input and
  /// outbuf to unused output and return number of non-reversable 
  /// conversions or -1 on error.
  extern (C) size_t libiconv (libiconv_t cd, void **inbuf,
			   size_t *inbytesleft,
			   void **outbuf,
			   size_t *outbytesleft);
  size_t iconv (iconv_t cd, void **inbuf, size_t *inbytesleft,
			   void **outbuf, size_t *outbytesleft)
  { return libiconv(cast(libiconv_t) cd, inbuf, inbytesleft, outbuf, outbytesleft); }

  /// close converter
  extern (C) int libiconv_close (libiconv_t cd);
  int iconv_close (iconv_t cd)
  { return libiconv_close(cast(libiconv_t) cd); }

} else { 

  // on POSIX systems iconv is built into libc so loading is automatic

  /// allocate a converter between charsets fromcode and tocode
  extern (C) iconv_t iconv_open (char *tocode, char *fromcode);

  /// convert inbuf to outbuf and set inbytesleft to unused input and
  /// outbuf to unused output and return number of non-reversable 
  /// conversions or -1 on error.
  extern (C) size_t iconv (iconv_t cd, void **inbuf,
			   size_t *inbytesleft,
			   void **outbuf,
			   size_t *outbytesleft);

  /// close converter
  extern (C) int iconv_close (iconv_t cd);

}
