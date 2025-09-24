#ifndef LIBWS__h
#define LIBWS__h

#ifdef __cplusplus
extern "C"
{
#endif

/** Major version of libws. */
#define LIBWS_VERSION_MAJOR 0
/** Minor version of libws. */
#define LIBWS_VERSION_MINOR 1
/** Patch version of libws. */
#define LIBWS_VERSION_PATCH 0

/* Define to 1 if you have the <dirent.h> header file. */
#ifndef HAVE_DIRENT_H
#define HAVE_DIRENT_H 1
#endif

/* Define to 1 if you have the <stddef.h> header file. */
#ifndef HAVE_STDDEF_H
#define HAVE_STDDEF_H 1
#endif

/* Define to 1 if you have the <stdio.h> header file. */
#ifndef HAVE_STDIO_H
#define HAVE_STDIO_H 1
#endif

/* Define to 1 if you have the <stdlib.h> header file. */
#ifndef HAVE_STDLIB_H
#define HAVE_STDLIB_H 1
#endif

/* Define to 1 if you have the <sys/stat.h> header file. */
#ifndef HAVE_SYS_STAT_H
#define HAVE_SYS_STAT_H 1
#endif

/* Define to 1 if you have the <sys/sendfile.h> header file. */
#ifndef HAVE_SYS_SENDFILE_H
#define HAVE_SYS_SENDFILE_H 1
#endif

/* Define to 1 if you have the <string.h> header file. */
#ifndef HAVE_STRING_H
#define HAVE_STRING_H 1
#endif

/* Define to 1 if you have the <unistd.h> header file. */
#ifndef HAVE_UNISTD_H
#define HAVE_UNISTD_H 1
#endif

/* Define to 1 if you have the <windows.h> header file. */
#ifndef HAVE_WINDOWS_H
/* #undef HAVE_WINDOWS_H */
#endif

/* Define to 1 if you have the `free' function. */
#ifndef HAVE_FREE
#define HAVE_FREE 1
#endif

/* Define to 1 if you have the `malloc' function. */
#ifndef HAVE_MALLOC
#define HAVE_MALLOC 1
#endif

/* Define to 1 if you have the `memset' function. */
#ifndef HAVE_MEMSET
#define HAVE_MEMSET 1
#endif

/* Define to 1 if you have the `memcpy' function. */
#ifndef HAVE_MEMCPY
#define HAVE_MEMCPY 1
#endif

/* Define to 1 if you have the `_snprintf_s' function. */
#ifndef HAVE__SNPRINTF_S
/* #undef HAVE__SNPRINTF_S */
#endif

/* Define to 1 if you have the `_snprintf' function. */
#ifndef HAVE__SNPRINTF
/* #undef HAVE__SNPRINTF */
#endif

/* Define to 1 if you have the `snprintf' function. */
#ifndef HAVE_SNPRINTF
#define HAVE_SNPRINTF 1
#endif

/* Define to 1 if you have the `vsnprintf' function. */
#ifndef HAVE_VSNPRINTF
#define HAVE_VSNPRINTF 1
#endif

/* Define to 1 if you build with Doxygen. */
#ifndef LIBWS_DOXYGEN
/* #undef LIBWS_DOXYGEN */
#endif

#ifdef HAVE_STDDEF_H
/* Required for size_t */
#include <stddef.h>
#endif

#ifndef LIBWS_MALLOC
#ifdef HAVE_MALLOC
/**
 * Defines the malloc function used by libws at compile time.
 *
 * @code
 * void* my_malloc(size_t size)
 * {
 *     // do something
 * }
 *
 * #define LIBWS_MALLOC my_malloc
 * @endcode
 */
#define LIBWS_MALLOC malloc
#else
#define LIBWS_MALLOC(size) NULL
#endif
#endif

#ifndef LIBWS_FREE
#ifdef HAVE_FREE
/**
 * Defines the free function used by libws at compile time.
 *
 * @code
 * void my_free(void* ptr)
 * {
 *     // do something
 * }
 *
 * #define LIBWS_FREE my_free
 * @endcode
 */
#define LIBWS_FREE free
#else
#define LIBWS_FREE(ptr)
#endif
#endif

#if !defined(__WINDOWS__) && (defined(WIN32) || defined(WIN64) || defined(_MSC_VER) || defined(_WIN32))
#define __WINDOWS__
#endif

#ifdef __WINDOWS__
#define LIBWS_CDECL __cdecl
#define LIBWS_STDCALL __stdcall

/* export symbols by default, this is necessary for copy pasting the C and header file */
#if !defined(LIBWS_HIDE_SYMBOLS) && !defined(LIBWS_IMPORT_SYMBOLS) && !defined(LIBWS_EXPORT_SYMBOLS)
#define LIBWS_EXPORT_SYMBOLS
#endif

#if defined(LIBWS_HIDE_SYMBOLS)
#define LIBWS_PUBLIC(type) type LIBWS_STDCALL
#elif defined(LIBWS_EXPORT_SYMBOLS)
#define LIBWS_PUBLIC(type) __declspec(dllexport) type LIBWS_STDCALL
#elif defined(LIBWS_IMPORT_SYMBOLS)
#define LIBWS_PUBLIC(type) __declspec(dllimport) type LIBWS_STDCALL
#endif
#else /* !__WINDOWS__ */
#define LIBWS_CDECL
#define LIBWS_STDCALL

#if (defined(__GNUC__) || defined(__SUNPRO_CC) || defined(__SUNPRO_C)) && defined(CJSON_API_VISIBILITY)
#define LIBWS_PUBLIC(type) __attribute__((visibility("default"))) type
#else
#define LIBWS_PUBLIC(type) type
#endif
#endif

    /** Struct for custom hooks configuration. */
    struct ws_hooks
    {
        /** Custom malloc function. */
        void *(LIBWS_CDECL *malloc_fn)(size_t size);

        /**  Custom free function. */
        void(LIBWS_CDECL *free_fn)(void *ptr);
    };

    /**
     * Register custom hooks.
     *
     * @code{.c}
     * struct ws_hooks hooks = { malloc, free };
     * ws_init_hooks(&hooks);
     * @endcode
     *
     * @param[in] hooks Hooks configuration
     */
    LIBWS_PUBLIC(void)
    ws_init_hooks(struct ws_hooks *hooks);

    enum ws_event
    {
        LIBWS_EVENT_CONNECTION_ERROR,
        LIBWS_EVENT_CONNECTED,
        LIBWS_EVENT_SENT,
        LIBWS_EVENT_RECEIVED,
        LIBWS_EVENT_CLOSED
    };

    struct ws;
    struct ws_client;
    struct lws_context;

    struct ws_connect_options
    {
        /* Libwebsockets context. */
        struct lws_context *context;
        /* Host to connect to. */
        const char *host;
        /* Port to connect to. */
        int port;
        /* Path to connect to. */
        const char *path;
        /* Callback to receive events. */
        int (*callback)(struct ws_client *client, enum ws_event event, void *user);
        /* Size of user data allocated per client. */
        size_t per_client_data_size;
    };

    struct ws_listen_options
    {
        /* Libwebsockets context. */
        struct lws_context *context;
        /* Port to listen to or 0. */
        int port;
        /* Callback to receive events. */
        int (*callback)(struct ws_client *client, enum ws_event event, void *user);
        /* Size of user data allocated per client. */
        size_t per_client_data_size;
    };

    /**
     * Connects to a server.
     *
     * @code{.c}
     * int client_callback(struct ws_client *client, enum ws_event event, void *user)
     * {
     *   switch(event)
     *   {
     *   case LIBWS_EVENT_CONNECTED:
     *     // connected to server
     *     break;
     *   case LIBWS_EVENT_RECEIVED:
     *     // received data from server
     *     break;
     *   default:
     *     break;
     *   }
     *
     *   return 0;
     * }
     * 
     * struct ws_connect_options options;
     * options.context = context;
     * options.host = "a.b.c.d";
     * options.port = 1234;
     * options.callback = client_callback;
     * struct ws* ws = ws_connect(&options);
     * @endcode
     *
     * @param[in] options Connect options
     * @return A new websocket, or NULL.
     */
    LIBWS_PUBLIC(struct ws *)
    ws_connect(const struct ws_connect_options *options);

    /**
     * Listens for connections.
     *
     * @code{.c}
     * int server_callback(struct ws_client *client, enum ws_event event, void *user)
     * {
     *   switch(event)
     *   {
     *   case LIBWS_EVENT_CONNECTED:
     *     // new client connected
     *     break;
     *   case LIBWS_EVENT_RECEIVED:
     *     // received data from client
     *     break;
     *   default:
     *     break;
     *   }
     *
     *   return 0;
     * }
     * 
     * struct ws_listen_options options;
     * options.context = context;
     * options.port = 1234;
     * options.callback = server_callback;
     * struct ws* ws = ws_connect(&options);
     * @endcode
     *
     * @param[in] options Listen options
     * @return A new websocket, or NULL.
     */
    LIBWS_PUBLIC(struct ws *)
    ws_listen(const struct ws_listen_options *options);

    /**
     * Closes and deletes a websocket.
     *
     * @param[in] ws Some websocket
     */
    LIBWS_PUBLIC(void)
    ws_delete(struct ws *ws);

    /**
     * Returns the port a websocket is connected or listens to.
     *
     * @return Port number.
     */
    LIBWS_PUBLIC(int)
    ws_get_port(struct ws* ws);

    /**
     * Returns a client on the websocket by index.
     *
     * @param[in] ws Some websocket
     * @param[in] index Index of the client
     * @return Client at index, or NULL.
     */
    LIBWS_PUBLIC(struct ws_client*)
    ws_get_client(struct ws* ws, size_t index);

    /**
     * Returns the number of clients on the websocket.
     *
     * @param[in] ws Some websocket
     * @return Number of clients.
     */
    LIBWS_PUBLIC(size_t)
    ws_get_num_clients(const struct ws* ws);

    /**
     * Returns the websocket associated with a client.
     *
     * @param[in] client Some client
     * @return Associated websocket.
     */
    LIBWS_PUBLIC(struct ws*)
    ws_get_websocket(const struct ws_client* client);

    /**
     * Sends data to a client.
     *
     * @code{.c}
     * const char *buf = "hello";
     * ws_send(client, (const void*)buf, 5);
     * @endcode
     *
     * @param[in] client Some client
     * @param[in] buf Buffer containing data to send
     * @param[in] size Buffer size
     * @return Number of bytes sent.
     */
    LIBWS_PUBLIC(void)
    ws_send(struct ws_client *client, const void *buf, size_t size);

    /**
     * Receives data from a client.
     *
     * @code{.c}
     * char buf[5];
     * ws_receive(client, (void*)&buf[0], 5);
     * @endcode
     *
     * @param[in] client Some client
     * @param[in] buf Buffer for storing received data
     * @param[in] size Buffer size
     * @return Number of bytes received.
     */
    LIBWS_PUBLIC(size_t)
    ws_receive(struct ws_client *client, void *buf, size_t size);

#ifdef __cplusplus
}
#endif

#endif
