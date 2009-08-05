module tinycurl.tinycurl;

import std.string;
import std.cstream;

extern(C)
	{
	alias void CURL;

	CURLcode curl_global_init(int flags);
	CURL* curl_easy_init();
	CURLcode curl_easy_perform(CURL *handle);
	CURLcode curl_easy_setopt(CURL *handle, CURLoption option, ...);
	char* curl_easy_escape (CURL *handle, char* string, int length);
	void curl_free (char *ptr);
	void curl_easy_cleanup(CURL *handle);
	}


const CURL_ERROR_SIZE = 256;
const CURL_GLOBAL_ALL = 3;

enum
	{
    CURLE_OK,
    CURLE_UNSUPPORTED_PROTOCOL,
    CURLE_FAILED_INIT,
    CURLE_URL_MALFORMAT,
    CURLE_URL_MALFORMAT_USER,
    CURLE_COULDNT_RESOLVE_PROXY,
    CURLE_COULDNT_RESOLVE_HOST,
    CURLE_COULDNT_CONNECT,
    CURLE_FTP_WEIRD_SERVER_REPLY,
    CURLE_FTP_ACCESS_DENIED,
    CURLE_FTP_USER_PASSWORD_INCORRECT,
    CURLE_FTP_WEIRD_PASS_REPLY,
    CURLE_FTP_WEIRD_USER_REPLY,
    CURLE_FTP_WEIRD_PASV_REPLY,
    CURLE_FTP_WEIRD_227_FORMAT,
    CURLE_FTP_CANT_GET_HOST,
    CURLE_FTP_CANT_RECONNECT,
    CURLE_FTP_COULDNT_SET_BINARY,
    CURLE_PARTIAL_FILE,
    CURLE_FTP_COULDNT_RETR_FILE,
    CURLE_FTP_WRITE_ERROR,
    CURLE_FTP_QUOTE_ERROR,
    CURLE_HTTP_RETURNED_ERROR,
    CURLE_WRITE_ERROR,
    CURLE_MALFORMAT_USER,
    CURLE_FTP_COULDNT_STOR_FILE,
    CURLE_READ_ERROR,
    CURLE_OUT_OF_MEMORY,
    CURLE_OPERATION_TIMEOUTED,
    CURLE_FTP_COULDNT_SET_ASCII,
    CURLE_FTP_PORT_FAILED,
    CURLE_FTP_COULDNT_USE_REST,
    CURLE_FTP_COULDNT_GET_SIZE,
    CURLE_HTTP_RANGE_ERROR,
    CURLE_HTTP_POST_ERROR,
    CURLE_SSL_CONNECT_ERROR,
    CURLE_BAD_DOWNLOAD_RESUME,
    CURLE_FILE_COULDNT_READ_FILE,
    CURLE_LDAP_CANNOT_BIND,
    CURLE_LDAP_SEARCH_FAILED,
    CURLE_LIBRARY_NOT_FOUND,
    CURLE_FUNCTION_NOT_FOUND,
    CURLE_ABORTED_BY_CALLBACK,
    CURLE_BAD_FUNCTION_ARGUMENT,
    CURLE_BAD_CALLING_ORDER,
    CURLE_INTERFACE_FAILED,
    CURLE_BAD_PASSWORD_ENTERED,
    CURLE_TOO_MANY_REDIRECTS,
    CURLE_UNKNOWN_TELNET_OPTION,
    CURLE_TELNET_OPTION_SYNTAX,
    CURLE_OBSOLETE,
    CURLE_SSL_PEER_CERTIFICATE,
    CURLE_GOT_NOTHING,
    CURLE_SSL_ENGINE_NOTFOUND,
    CURLE_SSL_ENGINE_SETFAILED,
    CURLE_SEND_ERROR,
    CURLE_RECV_ERROR,
    CURLE_SHARE_IN_USE,
    CURLE_SSL_CERTPROBLEM,
    CURLE_SSL_CIPHER,
    CURLE_SSL_CACERT,
    CURLE_BAD_CONTENT_ENCODING,
    CURLE_LDAP_INVALID_URL,
    CURLE_FILESIZE_EXCEEDED,
    CURLE_FTP_SSL_FAILED,
    CURLE_SEND_FAIL_REWIND,
    CURLE_SSL_ENGINE_INITFAILED,
    CURLE_LOGIN_DENIED,
    CURLE_TFTP_NOTFOUND,
    CURLE_TFTP_PERM,
    CURLE_TFTP_DISKFULL,
    CURLE_TFTP_ILLEGAL,
    CURLE_TFTP_UNKNOWNID,
    CURLE_TFTP_EXISTS,
    CURLE_TFTP_NOSUCHUSER,
    CURLE_CONV_FAILED,
    CURLE_CONV_REQD,
    CURLE_SSL_CACERT_BADFILE,
    CURL_LAST,
	}
alias int CURLcode;

enum
	{
    CURLOPT_FILE = 10001,
    CURLOPT_URL,
    CURLOPT_PORT = 3,
    CURLOPT_PROXY = 10004,
    CURLOPT_USERPWD,
    CURLOPT_PROXYUSERPWD,
    CURLOPT_RANGE,
    CURLOPT_INFILE = 10009,
    CURLOPT_ERRORBUFFER,
    CURLOPT_WRITEFUNCTION = 20011,
    CURLOPT_READFUNCTION,
    CURLOPT_TIMEOUT = 13,
    CURLOPT_INFILESIZE,
    CURLOPT_POSTFIELDS = 10015,
    CURLOPT_REFERER,
    CURLOPT_FTPPORT,
    CURLOPT_USERAGENT,
    CURLOPT_LOW_SPEED_LIMIT = 19,
    CURLOPT_LOW_SPEED_TIME,
    CURLOPT_RESUME_FROM,
    CURLOPT_COOKIE = 10022,
    CURLOPT_HTTPHEADER,
    CURLOPT_HTTPPOST,
    CURLOPT_SSLCERT,
    CURLOPT_SSLCERTPASSWD,
    CURLOPT_SSLKEYPASSWD = 10026,
    CURLOPT_CRLF = 27,
    CURLOPT_QUOTE = 10028,
    CURLOPT_WRITEHEADER,
    CURLOPT_COOKIEFILE = 10031,
    CURLOPT_SSLVERSION = 32,
    CURLOPT_TIMECONDITION,
    CURLOPT_TIMEVALUE,
    CURLOPT_CUSTOMREQUEST = 10036,
    CURLOPT_STDERR,
    CURLOPT_POSTQUOTE = 10039,
    CURLOPT_WRITEINFO,
    CURLOPT_VERBOSE = 41,
    CURLOPT_HEADER,
    CURLOPT_NOPROGRESS,
    CURLOPT_NOBODY,
    CURLOPT_FAILONERROR,
    CURLOPT_UPLOAD,
    CURLOPT_POST,
    CURLOPT_FTPLISTONLY,
    CURLOPT_FTPAPPEND = 50,
    CURLOPT_NETRC,
    CURLOPT_FOLLOWLOCATION,
    CURLOPT_TRANSFERTEXT,
    CURLOPT_PUT,
    CURLOPT_PROGRESSFUNCTION = 20056,
    CURLOPT_PROGRESSDATA = 10057,
    CURLOPT_AUTOREFERER = 58,
    CURLOPT_PROXYPORT,
    CURLOPT_POSTFIELDSIZE,
    CURLOPT_HTTPPROXYTUNNEL,
    CURLOPT_INTERFACE = 10062,
    CURLOPT_KRB4LEVEL,
    CURLOPT_SSL_VERIFYPEER = 64,
    CURLOPT_CAINFO = 10065,
    CURLOPT_MAXREDIRS = 68,
    CURLOPT_FILETIME,
    CURLOPT_TELNETOPTIONS = 10070,
    CURLOPT_MAXCONNECTS = 71,
    CURLOPT_CLOSEPOLICY,
    CURLOPT_FRESH_CONNECT = 74,
    CURLOPT_FORBID_REUSE,
    CURLOPT_RANDOM_FILE = 10076,
    CURLOPT_EGDSOCKET,
    CURLOPT_CONNECTTIMEOUT = 78,
    CURLOPT_HEADERFUNCTION = 20079,
    CURLOPT_HTTPGET = 80,
    CURLOPT_SSL_VERIFYHOST,
    CURLOPT_COOKIEJAR = 10082,
    CURLOPT_SSL_CIPHER_LIST,
    CURLOPT_HTTP_VERSION = 84,
    CURLOPT_FTP_USE_EPSV,
    CURLOPT_SSLCERTTYPE = 10086,
    CURLOPT_SSLKEY,
    CURLOPT_SSLKEYTYPE,
    CURLOPT_SSLENGINE,
    CURLOPT_SSLENGINE_DEFAULT = 90,
    CURLOPT_DNS_USE_GLOBAL_CACHE,
    CURLOPT_DNS_CACHE_TIMEOUT,
    CURLOPT_PREQUOTE = 10093,
    CURLOPT_DEBUGFUNCTION = 20094,
    CURLOPT_DEBUGDATA = 10095,
    CURLOPT_COOKIESESSION = 96,
    CURLOPT_CAPATH = 10097,
    CURLOPT_BUFFERSIZE = 98,
    CURLOPT_NOSIGNAL,
    CURLOPT_SHARE = 10100,
    CURLOPT_PROXYTYPE = 101,
    CURLOPT_ENCODING = 10102,
    CURLOPT_PRIVATE,
    CURLOPT_HTTP200ALIASES,
    CURLOPT_UNRESTRICTED_AUTH = 105,
    CURLOPT_FTP_USE_EPRT,
    CURLOPT_HTTPAUTH,
    CURLOPT_SSL_CTX_FUNCTION = 20108,
    CURLOPT_SSL_CTX_DATA = 10109,
    CURLOPT_FTP_CREATE_MISSING_DIRS = 110,
    CURLOPT_PROXYAUTH,
    CURLOPT_FTP_RESPONSE_TIMEOUT,
    CURLOPT_IPRESOLVE,
    CURLOPT_MAXFILESIZE,
    CURLOPT_INFILESIZE_LARGE = 30115,
    CURLOPT_RESUME_FROM_LARGE,
    CURLOPT_MAXFILESIZE_LARGE,
    CURLOPT_NETRC_FILE = 10118,
    CURLOPT_FTP_SSL = 119,
    CURLOPT_POSTFIELDSIZE_LARGE = 30120,
    CURLOPT_TCP_NODELAY = 121,
    CURLOPT_FTPSSLAUTH = 129,
    CURLOPT_IOCTLFUNCTION = 20130,
    CURLOPT_IOCTLDATA = 10131,
    CURLOPT_FTP_ACCOUNT = 10134,
    CURLOPT_COOKIELIST,
    CURLOPT_IGNORE_CONTENT_LENGTH = 136,
    CURLOPT_FTP_SKIP_PASV_IP,
    CURLOPT_FTP_FILEMETHOD,
    CURLOPT_LOCALPORT,
    CURLOPT_LOCALPORTRANGE,
    CURLOPT_CONNECT_ONLY,
    CURLOPT_CONV_FROM_NETWORK_FUNCTION = 20142,
    CURLOPT_CONV_TO_NETWORK_FUNCTION,
    CURLOPT_CONV_FROM_UTF8_FUNCTION,
    CURLOPT_MAX_SEND_SPEED_LARGE = 30145,
    CURLOPT_MAX_RECV_SPEED_LARGE,
    CURLOPT_FTP_ALTERNATIVE_TO_USER = 10147,
    CURLOPT_SOCKOPTFUNCTION = 20148,
    CURLOPT_SOCKOPTDATA = 10149,
    CURLOPT_SSL_SESSIONID_CACHE = 150,
    CURLOPT_LASTENTRY,
	}
alias int CURLoption;

class CURLRequest
	{
	private static bool initialised = false;

	private CURL* curl;
	private static char[][CURL*] buffers;
	private static char*[CURL*] errors;

	public char[] url;

	private bool set_opt (CURLoption opt, char[] str)
		{
		return curl_easy_setopt (curl, opt, std.string.toStringz (str)) == CURLE_OK;
		}

	private bool set_opt (CURLoption opt, int i)
		{
		return curl_easy_setopt (curl, opt, i) == CURLE_OK;
		}

	this (char[] url)
		{
		synchronized if (!initialised)
			{
			initialised = true;
			curl_global_init (CURL_GLOBAL_ALL);
			}

		this.url = url;
		curl = curl_easy_init ();
		set_opt (CURLOPT_URL, url);
		}

	char[] escape (byte[] bytes)
		{
		char* result = curl_easy_escape (curl, cast(char*)(bytes.dup.ptr), bytes.length);
		char[] r = std.string.toString (result).dup;
		curl_free (result);
		return r;
		}

	extern (C) static int callback (void* ptr, int size, int nmemb, void* stream)
		{
		char[] str = std.string.toString(cast(char*)ptr);

		if (str.length)
			{
			this.buffers[stream] ~= str[0 .. (size * nmemb)];
			}

		return size * nmemb;
		}

	public synchronized char[] get (char[] cookie = "", char[] useragent = "")
		{
		buffers[curl] = "";
		errors[curl] = (new char[CURL_ERROR_SIZE]).ptr;

		//set_opt(CURLOPT_VERBOSE, 1);

		if (cookie.length > 0)
			{
			set_opt (CURLOPT_COOKIE, cookie);
			}

		if (useragent.length > 0)
			{
			set_opt(CURLOPT_USERAGENT, useragent);
			}

		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, &callback);
		curl_easy_setopt(curl, CURLOPT_FILE, curl);
		curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, errors[curl]);
		CURLcode result = curl_easy_perform(curl);

		char[] ret = buffers[curl];
		buffers.remove (curl);

		if (result != CURLE_OK)
			{
			derr.writefln ("CURL get error: %s", std.string.toString (errors[curl]));
			curl_easy_cleanup (curl);
			curl = curl_easy_init ();
			set_opt (CURLOPT_URL, this.url);
			}

		errors.remove (curl);

		return ret;
		}

	public synchronized char[] post (char[] cookie = "", char[] data = "", char[] useragent = "")
		{
		buffers[curl] = "";
		errors[curl] = (new char[CURL_ERROR_SIZE]).ptr;

		set_opt (CURLOPT_POST, 1);

		if (cookie.length > 0)
			{
			set_opt (CURLOPT_COOKIE, cookie);
			}

		if (data.length > 0)
			{
			dout.writefln ("Post data: %s", data);
			set_opt (CURLOPT_POSTFIELDS, data);
			}

		if (useragent.length > 0)
			{
			set_opt (CURLOPT_USERAGENT, useragent);
			}

		curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, &callback);
		curl_easy_setopt(curl, CURLOPT_FILE, curl);
		curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, errors[curl]);
		CURLcode result = curl_easy_perform(curl);

		char[] ret = buffers[curl];
		buffers.remove (curl);

		if (result != CURLE_OK)
			{
			derr.writefln ("CURL post error: %s", std.string.toString (errors[curl]));
			curl_easy_cleanup (curl);
			curl = curl_easy_init ();
			set_opt (CURLOPT_URL, url);
			}

		errors.remove (curl);

		return ret;
		}
	}
