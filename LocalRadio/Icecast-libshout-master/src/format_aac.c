/* -*- c-basic-offset: 8; -*- */
/* aac.c: libshout AAC format handler
 *
 *  Copyright (C) 2010 Aupeo GmbH, Arthur Taylor <arthur@aupeo.com>
 *  Copyright (C) 2018 Ferncast GmbH, Bernd Geiser <bg@ferncast.de>
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public
 *  License along with this library; if not, write to the Free
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 * AAC frame handling courtesy Arthur Taylor
 * AAC LATMLOAS and USAC frame handling courtesy Bernd Geiser
 */

#include <stdlib.h>
#include <string.h>
//#include <malloc.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include <shout/shout.h>
#include "shout_private.h"

#define ADTS_HEADER_SIZE 8 /* Actual ADTS Header size -> 56 bits */

#define min(a, b) (a<b ? a : b)

static int sample_rates[] = {96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000};

typedef enum {
        SEEK,
        PARSE_HEADER,
        READ_FRAME
} ParseState_e;

typedef enum {
        ADTS,
        LATMLOAS
} Framing_e;

struct aac_data {
        ParseState_e state;
        unsigned char *buffer;
        int buffer_length;
        int buffer_allocated;
        unsigned int frame_length;
        int frames_sent;
        float frames_per_second;
        Framing_e framing;
};
typedef struct aac_data aac_data_t;

/* -- static prototypes -- */
static int process_local_buffer(shout_t *self, aac_data_t *data);

static int send_aac(shout_t *self, const unsigned char *buf, size_t len);

static void close_aac(shout_t *self);

int shout_open_aac(shout_t *self) {
        aac_data_t *aac_data;
        if (!(aac_data = (aac_data_t *) calloc(1, sizeof(aac_data_t))))
                return SHOUTERR_MALLOC;
        self->format_data = aac_data;

        memset(aac_data, 0, sizeof(*aac_data));

        aac_data->state = SEEK;
        aac_data->framing = ADTS;

        self->send = send_aac;
        self->close = close_aac;

        return SHOUTERR_SUCCESS;
}

int shout_open_aac_latmloas(shout_t *self) {
        aac_data_t *aac_data;
        if (!(aac_data = (aac_data_t *) calloc(1, sizeof(aac_data_t))))
                return SHOUTERR_MALLOC;
        self->format_data = aac_data;

        memset(aac_data, 0, sizeof(*aac_data));

        aac_data->state = SEEK;
        aac_data->framing = LATMLOAS;

        self->send = send_aac;
        self->close = close_aac;

        return SHOUTERR_SUCCESS;
}

static void copy_to_local_buffer(aac_data_t *data, const unsigned char *buf, size_t offset, size_t length) {
        data->buffer = malloc(length);
        memcpy(data->buffer, buf + offset, length);
        data->buffer_length = length;
        data->buffer_allocated = length;
}

static void append_to_local_buffer(aac_data_t *data, const unsigned char *buf, size_t length) {
        if (data->buffer_allocated - data->buffer_length < length) {
                data->buffer = realloc(data->buffer, data->buffer_length + length);
                data->buffer_allocated = data->buffer_length + length;
        }
        memcpy(data->buffer + data->buffer_length, buf, length);
        data->buffer_length += length;
}


static unsigned short getbits(unsigned char **stream, unsigned short *store, unsigned short *nStored, unsigned char n)
{
        const unsigned short BitMask[16 + 1] = {
                0x0,        0x1,        0x3,       0x7,       0xf,       0x1f,
                0x3f,       0x7f,       0xff,      0x1ff,     0x3ff,     0x7ff,
                0xfff,      0x1fff,     0x3fff,    0x7fff,    0xffff
        };
        unsigned short bits = 0;
        char missing = n - *nStored;
        if (missing > 0) {
                if (missing != 16) bits = *store << missing;
                *store = *(*stream)++;
                *nStored += 8;
        }
        *nStored -= n;
        return (bits | (*store >> *nStored)) & BitMask[n];
}

static void read_header_data(aac_data_t *data, int aac_fl) {
        if(data->framing == ADTS)
                {
                        int sr_idx = (data->buffer[2] & 0x3C) >> 2;
                        if(aac_fl)
                                data->frames_per_second = sample_rates[sr_idx] / (float)aac_fl;
                        else
                                data->frames_per_second = sample_rates[sr_idx] / 1024.f;
                        data->frame_length = ((((unsigned int) data->buffer[3] & 0x3)) << 11)
                                | (((unsigned int) data->buffer[4]) << 3) | (data->buffer[5] >> 5);
                }
        else if(data->framing == LATMLOAS)
                {
                        unsigned int i;
                        unsigned char *p = &data->buffer[0];
                        unsigned short store = *p++;
                        unsigned short nStored = 8;
                        (void)getbits(&p, &store, &nStored, 11); // header
                        data->frame_length = getbits(&p, &store, &nStored, 13) + 3;
                        if(!getbits(&p, &store, &nStored, 1)) // reuse streammux config
                                {
                                        (void)getbits(&p, &store, &nStored, 1); // audiomux version ( == 0);
                                        (void)getbits(&p, &store, &nStored, 1); // all streams same time framing
                                        (void)getbits(&p, &store, &nStored, 6); // subframes
                                        (void)getbits(&p, &store, &nStored, 4); // programs
                                        (void)getbits(&p, &store, &nStored, 3); // layers
                                        if(getbits(&p, &store, &nStored, 5) == 31) // aot
                                                (void)getbits(&p, &store, &nStored, 6);
                                        int rate;
                                        int srIdx = getbits(&p, &store, &nStored, 4); // samplerate
                                        if(srIdx == 15)
                                                rate = ((unsigned int)getbits(&p, &store, &nStored, 16) << 8) | (unsigned int)getbits(&p, &store, &nStored, 8);
                                        else
                                                rate = sample_rates[srIdx];
                                        if(aac_fl)
                                                data->frames_per_second = (float)rate / (float)aac_fl;
                                        else
                                                data->frames_per_second = (float)rate / 1024.;
                                }
                }
}

static void shift_data_left(aac_data_t *data, size_t amount) {
        size_t shift = min(amount, data->buffer_length);
        memmove(data->buffer, data->buffer + shift, data->buffer_length - shift);
        data->buffer_length -= shift;
}

static int send_frame(shout_t *self, aac_data_t *data) {
        int ret;
        if (data->buffer_length < data->frame_length)
                return SHOUTERR_SUCCESS;

        data->frames_sent++;
        self->senttime = (uint64_t) ((double) data->frames_sent * 1000000 / (double) data->frames_per_second);

        ret = shout_send_raw(self, data->buffer, data->frame_length);
        if (ret != data->frame_length)
                return SHOUTERR_SOCKET;

        shift_data_left(data, data->frame_length);
        data->state = PARSE_HEADER;
        return process_local_buffer(self, data);
}

static int valid_header_bytes(const unsigned char *buf, aac_data_t *data) {
        if(data->framing == ADTS)
                return buf[0] == 0xFF && (buf[1] & 0xF6) == 0xF0;
        else if(data->framing == LATMLOAS)
                return buf[0] == 0x56 && (buf[1] & 0xE0) == 0xE0;
        return 0;
}

static int process_local_buffer(shout_t *self, aac_data_t *data) {
        if (!data->buffer) {
                return SHOUTERR_SUCCESS;
        }
        switch (data->state) {
        case PARSE_HEADER:
                if (data->framing == ADTS && data->buffer_length < ADTS_HEADER_SIZE) {
                        return SHOUTERR_SUCCESS;
                }
                // TODO: check for what size?
                if (data->framing == LATMLOAS && data->buffer_length < 3) {
                        return SHOUTERR_SUCCESS;
                }
                if (!valid_header_bytes(data->buffer, data)) {
                        return SHOUTERR_SOCKET;
                }
                read_header_data(data, self->aac_fl);
                data->state = READ_FRAME;
                return process_local_buffer(self, data);
        case READ_FRAME:
                return send_frame(self, data);
        case SEEK:
                return SHOUTERR_SOCKET;
        }
        return SHOUTERR_SUCCESS;
}

static int send_aac(shout_t *self, const unsigned char *buf, size_t len) {
        aac_data_t *data = (aac_data_t *) self->format_data;
        size_t i = 0;
        switch (data->state) {
        case SEEK:
                while (i < len - 2) {
                        if (valid_header_bytes(buf + i, data)) {
                                copy_to_local_buffer(data, buf, i, len - i);
                                data->state = PARSE_HEADER;
                                if ((self->error = process_local_buffer(self, data)) != SHOUTERR_SUCCESS)
                                        return self->error;
                                break;
                        }
                        i++;
                }
                break;
        default:
                append_to_local_buffer(data, buf, len);
                return self->error = process_local_buffer(self, data);
        }
        return self->error = SHOUTERR_SUCCESS;
}

static void close_aac(shout_t *self) {
        aac_data_t *aac_data = (aac_data_t *) self->format_data;
        free(aac_data->buffer);
        free(aac_data);
}
