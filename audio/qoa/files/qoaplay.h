/*

Copyright (c) 2023, Dominic Szablewski - https://phoboslab.org
SPDX-License-Identifier: MIT
*/

#ifndef QOAPLAY_H
#define QOAPLAY_H

#ifdef __cplusplus
extern "C" {
#endif

#include "qoa.h"

#include <stdio.h>

/* -----------------------------------------------------------------------------
	qoaplay */

/* qoaplay is a tiny abstraction to read and decode a QOA file "on the fly".
It reads and decodes one frame at a time with minimal memory requirements.
qoaplay also provides some functions to seek to a specific frame. */

typedef struct {
	qoa_desc info;
	FILE *file;

	unsigned int first_frame_pos;
	unsigned int sample_pos;

	unsigned int buffer_len;
	unsigned char *buffer;

	unsigned int sample_data_pos;
	unsigned int sample_data_len;
	short *sample_data;
} qoaplay_desc;

qoaplay_desc *qoaplay_open(const char *path);

void qoaplay_close(qoaplay_desc *qp);

unsigned int qoaplay_decode_frame(qoaplay_desc *qp);

void qoaplay_rewind(qoaplay_desc *qp);

unsigned int qoaplay_decode(qoaplay_desc *qp, float *sample_data, int num_samples);

double qoaplay_get_duration(qoaplay_desc *qp);

double qoaplay_get_time(qoaplay_desc *qp);

int qoaplay_get_frame(qoaplay_desc *qp);

void qoaplay_seek_frame(qoaplay_desc *qp, int frame);

#ifdef __cplusplus
}
#endif
#endif /* QOAPLAY_H */
