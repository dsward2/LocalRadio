//
//  main.c
//  IcecastSourceClient
//
//  Created by Douglas Ward on 11/14/18.
//  Copyright © 2018 ArkPhone LLC. All rights reserved.
//



#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/un.h>
#include <sys/event.h>
#include <sys/ioctl.h>
#include <sys/sysctl.h>
//#include <sys/signal.h>
#include <signal.h>

#include <net/if.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <arpa/telnet.h>
#include <arpa/inet.h>

#include <err.h>
#include <errno.h>
#include <limits.h>
#include <netdb.h>
#include <poll.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <string.h>
#include <getopt.h>
#include <fcntl.h>
#include <pthread.h>

// use local version of shout.h for modified libshout to support AAC
#include "shout.h"


const char * argMode = "";
const char * argUserName = "source";
const char * argPassword = "missing_password";
const char * argHost = "localhost";
const char * argPort = "17003";
const char * argBitrate = "128000";
const char * argIcecastMountName = "localradio.aac";
const char * argCertificatesPath = "";


int runIcecastSource()
{
    shout_t *shout;
    unsigned char buff[4096];
    long read, ret, total;

    fprintf(stderr, "IcecastSourceClient - runIcecastSource start connection to Icecast server\n");
    
    //char * icecastServerCertificateFilePath = strcat((char *)argCertificatesPath, "icecastServer.pem");
    //char * certificateAuthorityPath = strcat((char *)argCertificatesPath, "IcecastCA.pem");

    shout_init();

    if (!(shout = shout_new())) {
        fprintf(stderr, "IcecastSourceClient - Could not allocate shout_t\n");
        return 1;
    }

    if (shout_set_host(shout, argHost) != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting hostname: %s\n", shout_get_error(shout));
        return 1;
    }

    if (shout_set_protocol(shout, SHOUT_PROTOCOL_HTTP) != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting protocol: %s\n", shout_get_error(shout));
        return 1;
    }

    unsigned short port = atoi(argPort);
    if (shout_set_port(shout, port) != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting port: %s\n", shout_get_error(shout));
        return 1;
    }

    if (shout_set_password(shout, argPassword) != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting password: %s\n", shout_get_error(shout));
        return 1;
    }
    if (shout_set_mount(shout, "/localradio.aac") != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting mount: %s\n", shout_get_error(shout));
        return 1;
    }

    // Use http, not https, sending to server on same host
    char urlString[256];
    snprintf((char *)&urlString, 255, "http://%s/localradio.aac", argHost);
    if (shout_set_url(shout, (char *)&urlString) != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting mount: %s\n", shout_get_error(shout));
        return 1;
    }

    if (shout_set_user(shout, argUserName) != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting user: %s\n", shout_get_error(shout));
        return 1;
    }
    
    if (shout_set_name(shout, "LocalRadio") != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting name (LocalRadio): %s\n", shout_get_error(shout));
        return 1;
    }

    if (shout_set_description(shout, "LocalRadio - https://github.com/dsward2/LocalRadio") != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting name (LocalRadio): %s\n", shout_get_error(shout));
        return 1;
    }

    if (shout_set_format(shout, SHOUT_FORMAT_AAC) != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting format: %s\n", shout_get_error(shout));
        return 1;
    }

    if (shout_set_public(shout, 0) != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting public: %s\n", shout_get_error(shout));
        return 1;
    }

    if (shout_set_tls(shout, SHOUT_TLS_AUTO) != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting TLS: %s\n", shout_get_error(shout));
        return 1;
    }

    /*
    if (shout_set_tls(shout, SHOUT_TLS_AUTO) != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting TLS: %s\n", shout_get_error(shout));
        return 1;
    }

    // Set a CA cert file for checking. If you use a self signed server cert
    // you can pass this cert using this function for verification.
    // Default: operating system's default
    if (shout_set_ca_file(shout, certificateAuthorityPath) != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting certificated authority: %s\n", shout_get_error(shout));
        return 1;
    }
    
    
    if (shout_set_ca_directory(shout, argCertificatesPath) != SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Error setting certificate directory: %s\n", shout_get_error(shout));
        return 1;
    }

    // Set a client certificate for TLS connections.
    // This must be in PEM format with both cert and private key in the same file.
    // Default: none.
    if (shout_set_client_certificate(shout, icecastServerCertificateFilePath) != SHOUTERR_SUCCESS) {
        fprintf(stderr, "Error setting client certificate: %s\n", shout_get_error(shout));
        return 1;
    }
    */

    if (shout_open(shout) == SHOUTERR_SUCCESS) {
        fprintf(stderr, "IcecastSourceClient - Connected to server...\n");
        total = 0;
        while (1) {
            read = fread(buff, 1, sizeof(buff), stdin);
            total = total + read;

            if (read > 0) {
                ret = shout_send(shout, buff, read);
                if (ret != SHOUTERR_SUCCESS) {
                    fprintf(stderr, "IcecastSourceClient - DEBUG: Send error: %s\n", shout_get_error(shout));
                    break;
                }
            } else {
                break;
            }

            shout_sync(shout);
        }
    } else {
        fprintf(stderr, "IcecastSourceClient - Error connecting: %s\n", shout_get_error(shout));
    }

    shout_close(shout);

    shout_shutdown();
 
    fprintf(stderr, "IcecastSourceClient - terminating\n");

    return 0;
}




int main(int argc, char **argv)
{
    int                 retVal;
    bool                success;
    
    //raise(SIGSTOP); // Stop and wait for debugger. Click the Debugger's Resume button to continue execution

    fprintf(stderr, "IcecastSourceClient main() started\n");

    retVal = EXIT_FAILURE;
    success = true;
    
    for (int i = 0; i < argc; i++)
    {
        char * argStringPtr = (char *)argv[i];
        
        if (strcmp(argStringPtr, "-u") == 0)        // user name
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-u") == 0)
        {
            argUserName = argStringPtr;
            argMode = "";
        }
        else if (strcmp(argStringPtr, "-pw") == 0)   // password
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-pw") == 0)
        {
            argPassword = argStringPtr;
            argMode = "";
        }
        else if (strcmp(argStringPtr, "-h") == 0)   // host for source connection
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-h") == 0)
        {
            argHost = argStringPtr;
            argMode = "";
        }
        else if (strcmp(argStringPtr, "-p") == 0)   // port
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-p") == 0)
        {
            argPort = argStringPtr;
            argMode = "";
        }
        else if (strcmp(argStringPtr, "-b") == 0)   // bitrate
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-b") == 0)
        {
            argBitrate = argStringPtr;
            argMode = "";
        }
        else if (strcmp(argStringPtr, "-m") == 0)   // Icecast mount name
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-m") == 0)
        {
            argIcecastMountName = argStringPtr;
            argMode = "";
        }
        else if (strcmp(argStringPtr, "-cp") == 0)   // Icecast certificates path
        {
            argMode = argStringPtr;
        }
        else if (strcmp(argMode, "-cp") == 0)
        {
            argCertificatesPath = argStringPtr;
            argMode = "";
        }
    }

    runIcecastSource();
    
    return retVal;
}

