/*
 * libwebsockets - small server side websockets and web server implementation
 *
 * Copyright (C) 2010 - 2019 Andy Green <andy@warmcat.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

/** @file */

#define LIBWEBSOCKET_H_3060898B846849FF9F88F5DB59B5950C

#include <cstddef>
#include <cstdarg>

extern "C" {

#include "lws_config.h"

/* NetBSD */
#define ETHER_ADDR_LEN 6
	#include <sys/ethernet.h>
		#define ETHER_ADDR_LEN ETHERADDRL
#define LWS_ETHER_ADDR_LEN ETHER_ADDR_LEN

#include <stddef.h>
#include <string.h>
#include <stdlib.h>


/* place for one-shot opaque forward references */

typedef struct lws_context * lws_ctx_t;
struct lws_dsh;

/*
 * CARE: everything using cmake defines needs to be below here
 */

#define LWS_US_PER_SEC ((lws_usec_t)1000000)
#define LWS_MS_PER_SEC ((lws_usec_t)1000)
#define LWS_US_PER_MS ((lws_usec_t)1000)
#define LWS_NS_PER_US ((lws_usec_t)1000)

#define LWS_KI (1024)
#define LWS_MI (LWS_KI * 1024)
#define LWS_GI (LWS_MI * 1024)
#define LWS_TI ((uint64_t)LWS_GI * 1024)
#define LWS_PI ((uint64_t)LWS_TI * 1024)

#define LWS_US_TO_MS(x) ((x + (LWS_US_PER_MS / 2)) / LWS_US_PER_MS)

#define LWS_FOURCC(a, b, c, d) ((a << 24) | (b << 16) | (c << 8) | d)

#define lws_intptr_t intptr_t
typedef unsigned long long lws_intptr_t;

#define WIN32_LEAN_AND_MEAN

#define _O_RDONLY	0x0000
#define O_RDONLY	_O_RDONLY

typedef unsigned int uid_t;
typedef unsigned int gid_t;
typedef unsigned short sa_family_t;
typedef unsigned int useconds_t;
typedef int suseconds_t;

#define LWS_INLINE __inline
#define LWS_VISIBLE
#define LWS_WARN_UNUSED_RESULT
#define LWS_WARN_DEPRECATED
#define LWS_FORMAT(string_index)

#define LWS_EXTERN extern __declspec(dllexport)
#define LWS_EXTERN extern __declspec(dllimport)

#define LWS_EXTERN
#define LWS_VISIBLE

#define LWS_EXTERN

#define LWS_INVALID_FILE INVALID_HANDLE_VALUE
#define LWS_SOCK_INVALID (INVALID_SOCKET)
#define LWS_O_RDONLY _O_RDONLY
#define LWS_O_WRONLY _O_WRONLY
#define LWS_O_CREAT _O_CREAT
#define LWS_O_TRUNC _O_TRUNC

#define __func__ __FUNCTION__

#include <unistd.h>



#define LWS_INLINE inline
#define LWS_O_RDONLY O_RDONLY
#define LWS_O_WRONLY O_WRONLY
#define LWS_O_CREAT O_CREAT
#define LWS_O_TRUNC O_TRUNC

#include <poll.h>
#include <netdb.h>
#define LWS_INVALID_FILE -1
#define LWS_SOCK_INVALID (-1)
#define getdtablesize() (30)
#define LWS_INVALID_FILE NULL
#define LWS_SOCK_INVALID (-1)
#define LWS_INVALID_FILE NULL
#define LWS_SOCK_INVALID (-1)


/* warn_unused_result attribute only supported by GCC 3.4 or later */
#define LWS_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
#define LWS_WARN_UNUSED_RESULT

/* this is only set when we're building lws itself shared */
#define LWS_VISIBLE __attribute__((visibility("default")))
#define LWS_EXTERN extern

#define LWS_VISIBLE
#define LWS_EXTERN extern
/*
 * If we explicitly say hidden here, symbols exist as T but
 * cannot be imported at link-time.
 */
#define LWS_VISIBLE
#define LWS_EXTERN


#define LWS_WARN_DEPRECATED __attribute__ ((deprecated))
#undef printf
#define LWS_FORMAT(string_index) __attribute__ ((format(printf, string_index, string_index+1)))

#define LWS_VISIBLE
#define LWS_WARN_UNUSED_RESULT
#define LWS_WARN_DEPRECATED
#define LWS_FORMAT(string_index)
#define LWS_EXTERN extern



#define random rand





/*
 * Include user-controlled settings for windows from
 * <wolfssl-root>/IDE/WIN/user_settings.h
 */
#include <IDE/WIN/user_settings.h>
#include <cyassl/ctaocrypt/settings.h>
#include <cyassl/openssl/ssl.h>
#include <cyassl/error-ssl.h>

/*
 * Include user-controlled settings for windows from
 * <wolfssl-root>/IDE/WIN/user_settings.h
 */
/* this filepath is passed to us but without quotes or <> */
/* AMAZON RTOS has its own setting via MTK_MBEDTLS_CONFIG_FILE */
#undef MBEDTLS_CONFIG_FILE
#define MBEDTLS_CONFIG_FILE <mbedtls/esp_config.h>


#define MBEDTLS_PRIVATE(_q) _q

#define MBEDTLS_PRIVATE_V30_ONLY(_q) MBEDTLS_PRIVATE(_q)
#define MBEDTLS_PRIVATE_V30_ONLY(_q) _q


/*
 * Helpers for pthread mutex in user code... if lws is built for
 * multiple service threads, these resolve to pthread mutex
 * operations.  In the case LWS_MAX_SMP is 1 (the default), they
 * are all NOPs and no pthread type or api is referenced.
 */


#include <pthread.h>

#define lws_pthread_mutex(name) pthread_mutex_t name;

static LWS_INLINE void
lws_pthread_mutex_init(pthread_mutex_t *lock)
{
	pthread_mutex_init(lock, NULL);
}

static LWS_INLINE void
lws_pthread_mutex_destroy(pthread_mutex_t *lock)
{
	pthread_mutex_destroy(lock);
}

static LWS_INLINE void
lws_pthread_mutex_lock(pthread_mutex_t *lock)
{
	pthread_mutex_lock(lock);
}

static LWS_INLINE void
lws_pthread_mutex_unlock(pthread_mutex_t *lock)
{
	pthread_mutex_unlock(lock);
}

#define lws_pthread_mutex(name)
#define lws_pthread_mutex_init(_a)
#define lws_pthread_mutex_destroy(_a)
#define lws_pthread_mutex_lock(_a)
#define lws_pthread_mutex_unlock(_a)


#define CONTEXT_PORT_NO_LISTEN -1
#define CONTEXT_PORT_NO_LISTEN_SERVER -2

#include <libwebsockets/lws-logs.h>


#include <stddef.h>

#define lws_container_of(P,T,M)	((T *)((char *)(P) - offsetof(T, M)))
#define LWS_ALIGN_TO(x, bou) x += ((bou) - ((x) % (bou))) % (bou)

struct lws;

/* api change list for user code to test against */

#define LWS_FEATURE_SERVE_HTTP_FILE_HAS_OTHER_HEADERS_ARG

/* the struct lws_protocols has the id field present */
#define LWS_FEATURE_PROTOCOLS_HAS_ID_FIELD

/* you can call lws_get_peer_write_allowance */
#define LWS_FEATURE_PROTOCOLS_HAS_PEER_WRITE_ALLOWANCE

/* extra parameter introduced in 917f43ab821 */
#define LWS_FEATURE_SERVE_HTTP_FILE_HAS_OTHER_HEADERS_LEN

/* File operations stuff exists */
#define LWS_FEATURE_FOPS

/* Mounts have extra no_cache member */
#define LWS_FEATURE_MOUNT_NO_CACHE


typedef SOCKET lws_sockfd_type;
typedef int lws_filefd_type;
typedef HANDLE lws_filefd_type;


#define lws_pollfd pollfd
#define LWS_POLLHUP	(POLLHUP)
#define LWS_POLLIN	(POLLRDNORM | POLLRDBAND)
#define LWS_POLLOUT	(POLLWRNORM)



typedef int lws_sockfd_type;
typedef int lws_filefd_type;

struct timeval {
	time_t         	tv_sec;
	unsigned int    tv_usec;
};
// #include <poll.h>
#define lws_pollfd pollfd

struct timezone;

int gettimeofday(struct timeval *tv, struct timezone *tz);

    /* Internet address. */
    struct in_addr {
        uint32_t       s_addr;     /* address in network byte order */
    };

typedef unsigned short sa_family_t;
typedef unsigned short in_port_t;
typedef uint32_t socklen_t;


           struct addrinfo {
               int              ai_flags;
               int              ai_family;
               int              ai_socktype;
               int              ai_protocol;
               socklen_t        ai_addrlen;
               struct sockaddr *ai_addr;
               char            *ai_canonname;
               struct addrinfo *ai_next;
           };

ssize_t recv(int sockfd, void *buf, size_t len, int flags);
ssize_t send(int sockfd, const void *buf, size_t len, int flags);
ssize_t read(int fd, void *buf, size_t count);
int getsockopt(int sockfd, int level, int optname,
                      void *optval, socklen_t *optlen);
       int setsockopt(int sockfd, int level, int optname,
                      const void *optval, socklen_t optlen);
int connect(int sockfd, const struct sockaddr *addr,
                   socklen_t addrlen);

extern int errno;

uint16_t ntohs(uint16_t netshort);
uint16_t htons(uint16_t hostshort);

int bind(int sockfd, const struct sockaddr *addr,
                socklen_t addrlen);


#define  MSG_NOSIGNAL 0x4000
#define	EAGAIN		11
#define EINTR		4
#define EWOULDBLOCK	EAGAIN
#define	EADDRINUSE	98	
#define INADDR_ANY	0
#define AF_INET		2
#define SHUT_WR 1
#define AF_UNSPEC	0
#define PF_UNSPEC	0
#define SOCK_STREAM	1
#define SOCK_DGRAM	2
# define AI_PASSIVE	0x0001
#define IPPROTO_UDP	17
#define SOL_SOCKET	1
#define SO_SNDBUF	7
#define	EISCONN		106	
#define	EALREADY	114
#define	EINPROGRESS	115
int shutdown(int sockfd, int how);
int close(int fd);
int atoi(const char *nptr);
long long atoll(const char *nptr);

int socket(int domain, int type, int protocol);
       int getaddrinfo(const char *node, const char *service,
                       const struct addrinfo *hints,
                       struct addrinfo **res);

       void freeaddrinfo(struct addrinfo *res);

struct lws_pollfd
{
        int fd;                     /* File descriptor to poll.  */
        short int events;           /* Types of events poller cares about.  */
        short int revents;          /* Types of events that actually occurred.  */
};

int poll(struct pollfd *fds, int nfds, int timeout);

#define LWS_POLLHUP (0x18)
#define LWS_POLLIN (1)
#define LWS_POLLOUT (4)
struct lws_pollfd;
struct sockaddr_in;
#define lws_pollfd pollfd
#define LWS_POLLHUP (POLLHUP | POLLERR)
#define LWS_POLLIN (POLLIN)
#define LWS_POLLOUT (POLLOUT)


/* ... */
#define ssize_t SSIZE_T


/* !!! >:-[  */
typedef __int64 int64_t;
typedef unsigned __int64 uint64_t;
typedef __int32 int32_t;
typedef unsigned __int32 uint32_t;
typedef __int16 int16_t;
typedef unsigned __int16 uint16_t;
typedef unsigned __int8 uint8_t;
typedef unsigned int uint32_t;
typedef unsigned short uint16_t;
typedef unsigned char uint8_t;

typedef int64_t lws_usec_t;
typedef unsigned long long lws_filepos_t;
typedef long long lws_fileofs_t;
typedef uint32_t lws_fop_flags_t;

#define lws_concat_temp(_t, _l) (_t + sizeof(_t) - _l)
#define lws_concat_used(_t, _l) (sizeof(_t) - _l)

/** struct lws_pollargs - argument structure for all external poll related calls
 * passed in via 'in' */
struct lws_pollargs {
	lws_sockfd_type fd;	/**< applicable socket descriptor */
	int events;		/**< the new event mask */
	int prev_events;	/**< the previous event mask */
};

#define LWS_SIZEOFPTR ((int)sizeof (void *))

#define _LWS_PAD_SIZE 16	/* Intel recommended for best performance */
#define _LWS_PAD_SIZE LWS_SIZEOFPTR   /* Size of a pointer on the target arch */
#define _LWS_PAD(n) (((n) % _LWS_PAD_SIZE) ? \
		((n) + (_LWS_PAD_SIZE - ((n) % _LWS_PAD_SIZE))) : (n))
/* last 2 is for lws-meta */
#define LWS_PRE _LWS_PAD(4 + 10 + 2)
/* used prior to 1.7 and retained for backward compatibility */
#define LWS_SEND_BUFFER_PRE_PADDING LWS_PRE
#define LWS_SEND_BUFFER_POST_PADDING 0



struct lws_extension; /* needed even with ws exts disabled for create context */
struct lws_token_limits;
struct lws_protocols;
struct lws_context;
struct lws_tokens;
struct lws_vhost;
struct lws;

/* Generic stateful operation return codes */

typedef enum {
	LWS_SRET_OK		= 0,
	LWS_SRET_WANT_INPUT     = (1 << 16),
	LWS_SRET_WANT_OUTPUT    = (1 << 17),
	LWS_SRET_FATAL          = (1 << 18),
	LWS_SRET_NO_FURTHER_IN  = (1 << 19),
	LWS_SRET_NO_FURTHER_OUT = (1 << 20),
	LWS_SRET_AWAIT_RETRY    = (1 << 21),
	LWS_SRET_YIELD          = (1 << 22), /* return to the event loop and continue */
} lws_stateful_ret_t;

typedef struct lws_fixed3232 {
	int32_t		whole;	/* signed 32-bit int */
	int32_t		frac;	/* signed frac proportion from 0 to (100M - 1) */
} lws_fx_t;

#define LWS_FX_FRACTION_MSD 100000000
#define lws_neg(a) (a->whole < 0 || a->frac < 0)
#define lws_fx_set(a, x, y) { a.whole = x; a.frac = x < 0 ? -y : y; }
#define lws_fix64(a) (((int64_t)a->whole << 32) + \
		(((1ll << 32) * (a->frac < 0 ? -a->frac : a->frac)) / LWS_FX_FRACTION_MSD))
#define lws_fix64_abs(a) \
	((((int64_t)(a->whole < 0 ? (-a->whole) : a->whole) << 32) + \
			(((1ll << 32) * (a->frac < 0 ? -a->frac : a->frac)) / LWS_FX_FRACTION_MSD)))

#define lws_fix3232(a, a64) { a->whole = (int32_t)(a64 >> 32); \
			      a->frac = (int32_t)((100000000 * (a64 & 0xffffffff)) >> 32); }

LWS_VISIBLE LWS_EXTERN const lws_fx_t *
lws_fx_add(lws_fx_t *r, const lws_fx_t *a, const lws_fx_t *b);

LWS_VISIBLE LWS_EXTERN const lws_fx_t *
lws_fx_sub(lws_fx_t *r, const lws_fx_t *a, const lws_fx_t *b);

LWS_VISIBLE LWS_EXTERN const lws_fx_t *
lws_fx_mul(lws_fx_t *r, const lws_fx_t *a, const lws_fx_t *b);

LWS_VISIBLE LWS_EXTERN const lws_fx_t *
lws_fx_div(lws_fx_t *r, const lws_fx_t *a, const lws_fx_t *b);

LWS_VISIBLE LWS_EXTERN const lws_fx_t *
lws_fx_sqrt(lws_fx_t *r, const lws_fx_t *a);

LWS_VISIBLE LWS_EXTERN int
lws_fx_comp(const lws_fx_t *a, const lws_fx_t *b);

LWS_VISIBLE LWS_EXTERN int
lws_fx_roundup(const lws_fx_t *a);

LWS_VISIBLE LWS_EXTERN int
lws_fx_rounddown(const lws_fx_t *a);

LWS_VISIBLE LWS_EXTERN const char *
lws_fx_string(const lws_fx_t *a, char *buf, size_t size);

#include <libwebsockets/lws-dll2.h>
#include <libwebsockets/lws-map.h>

#include <libwebsockets/lws-fault-injection.h>
#include <libwebsockets/lws-backtrace.h>
#include <libwebsockets/lws-timeout-timer.h>
#include <libwebsockets/lws-cache-ttl.h>
#include <libwebsockets/lws-state.h>
#include <libwebsockets/lws-retry.h>
#include <libwebsockets/lws-adopt.h>
#include <libwebsockets/lws-network-helper.h>
#include <libwebsockets/lws-metrics.h>

#include <libwebsockets/lws-ota.h>
#include <libwebsockets/lws-system.h>
#include <libwebsockets/lws-callbacks.h>

#include <libwebsockets/lws-ws-close.h>
#include <libwebsockets/lws-ws-state.h>
#include <libwebsockets/lws-ws-ext.h>

#include <libwebsockets/lws-protocols-plugins.h>

#include <libwebsockets/lws-context-vhost.h>

#include <libwebsockets/lws-conmon.h>

#include <libwebsockets/lws-client.h>
#include <libwebsockets/lws-http.h>
#include <libwebsockets/lws-spa.h>
#include <libwebsockets/lws-purify.h>
#include <libwebsockets/lws-misc.h>
#include <libwebsockets/lws-dsh.h>
#include <libwebsockets/lws-service.h>
#include <libwebsockets/lws-write.h>
#include <libwebsockets/lws-writeable.h>
#include <libwebsockets/lws-ring.h>
#include <libwebsockets/lws-sha1-base64.h>
#include <libwebsockets/lws-x509.h>
#include <libwebsockets/lws-cgi.h>
#include <libwebsockets/lws-vfs.h>
#include <libwebsockets/lws-gencrypto.h>

#include <libwebsockets/lws-lejp.h>
#include <libwebsockets/lws-lecp.h>
#include <libwebsockets/lws-cose.h>
#include <libwebsockets/lws-struct.h>
#include <libwebsockets/lws-threadpool.h>
#include <libwebsockets/lws-tokenize.h>
#include <libwebsockets/lws-lwsac.h>
#include <libwebsockets/lws-fts.h>
#include <libwebsockets/lws-diskcache.h>
#include <libwebsockets/lws-secure-streams.h>
#include <libwebsockets/lws-secure-streams-serialization.h>
#include <libwebsockets/lws-secure-streams-policy.h>
#include <libwebsockets/lws-secure-streams-client.h>
#include <libwebsockets/lws-secure-streams-transport-proxy.h>
#include <libwebsockets/lws-jrpc.h>

#include <libwebsockets/lws-async-dns.h>


#include <libwebsockets/lws-tls-sessions.h>


#include <libwebsockets/lws-genhash.h>
#include <libwebsockets/lws-genrsa.h>
#include <libwebsockets/lws-genaes.h>
#include <libwebsockets/lws-genec.h>

#include <libwebsockets/lws-jwk.h>
#include <libwebsockets/lws-jose.h>
#include <libwebsockets/lws-jws.h>
#include <libwebsockets/lws-jwe.h>


#include <libwebsockets/lws-eventlib-exports.h>
#include <libwebsockets/lws-i2c.h>
#include <libwebsockets/lws-spi.h>
#include <libwebsockets/lws-gpio.h>
#include <libwebsockets/lws-bb-i2c.h>
#include <libwebsockets/lws-bb-spi.h>
#include <libwebsockets/lws-button.h>
#include <libwebsockets/lws-led.h>
#include <libwebsockets/lws-pwm.h>
#include <libwebsockets/lws-upng.h>
#include <libwebsockets/lws-jpeg.h>
#include <libwebsockets/lws-display.h>
#include <libwebsockets/lws-dlo.h>
#include <libwebsockets/lws-ssd1306-i2c.h>
#include <libwebsockets/lws-ili9341-spi.h>
#include <libwebsockets/lws-spd1656-spi.h>
#include <libwebsockets/lws-uc8176-spi.h>
#include <libwebsockets/lws-ssd1675b-spi.h>
#include <libwebsockets/lws-settings.h>
#include <libwebsockets/lws-netdev.h>

#include <libwebsockets/lws-html.h>

}
