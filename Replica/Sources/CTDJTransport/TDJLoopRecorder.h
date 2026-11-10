#ifndef TDJ_LOOP_RECORDER_H
#define TDJ_LOOP_RECORDER_H

typedef struct {
    float left, right, previous_left, previous_right;
    uint16_t layer;
} loop_sample;

typedef struct {
    uint32_t capacity, count;
    uint32_t beats, layer;
    uint64_t discarded[1024];
    double next_beat, first_beat, length_beats, position;
    bool armed, recording, playing, overdub, undone, play_after;
    double wet;
    ramp mix;
    loop_sample samples[];
} loop_recorder;

static loop_recorder *loop_recorder_create(double rate) {
    double frames = ceil(rate * 64);
    if (frames <= 0 || frames > UINT32_MAX ||
        frames > (SIZE_MAX - sizeof(loop_recorder)) / sizeof(loop_sample))
        return NULL;
    size_t bytes = sizeof(loop_recorder) + (size_t)frames * sizeof(loop_sample);
    loop_recorder *recorder = malloc(bytes);
    if (!recorder)
        return NULL;
    // Commit the buffer pages before the render thread writes to them.
    volatile unsigned char *pages = (volatile unsigned char *)recorder;
    for (size_t i = 0; i < bytes; i += 4096)
        pages[i] = 0;
    *recorder = (loop_recorder){.capacity = (uint32_t)frames, .beats = 4};
    return recorder;
}

static void loop_recorder_clear(loop_recorder *r) {
    r->count = 0;
    r->layer = 0;
    r->position = 0;
    r->armed = r->recording = r->playing = r->overdub = r->undone = false;
    r->mix = (ramp){0};
}

static int loop_recorder_state(const loop_recorder *r) {
    return (r->armed ? 1 : 0) | (r->recording ? 2 : 0) | (r->playing ? 4 : 0) |
           (r->overdub ? 8 : 0) | (r->count && !r->recording ? 16 : 0) |
           (r->layer ? 32 : 0) | (r->undone ? 64 : 0);
}

static void loop_recorder_finish(loop_recorder *r, double beats) {
    r->recording = false;
    r->playing = r->play_after && r->count > 0;
    r->length_beats = fmax(1, beats);
    r->position = 0;
}

static bool loop_recorder_control(loop_recorder *r, int action, double value, double beat, double rate, double bpm) {
    switch (action) {
    case TDJ_LOOP_REC_WET:
        if (!isfinite(value) || value < 0 || value > 1)
            return false;
        r->wet = value;
        break;
    case TDJ_LOOP_REC_SIZE:
        if (!r->armed && !r->recording && !r->count)
            r->beats = r->beats < 32 ? r->beats * 2 : 4;
        break;
    case TDJ_LOOP_REC_RECORD:
        if (r->overdub) {
            r->overdub = false;
        } else if (r->recording) {
            r->next_beat = fmin(r->next_beat, floor(beat) + 1);
        } else if (r->armed) {
            r->armed = false;
        } else if (r->count) {
            if (r->layer == UINT16_MAX)
                return false;
            r->layer++;
            r->discarded[r->layer / 64] &= ~(UINT64_C(1) << (r->layer % 64));
            r->undone = false;
            if (!r->playing)
                r->position = 0;
            r->playing = r->overdub = true;
        } else {
            if (r->beats * rate * 60 / bpm > r->capacity)
                return false;
            r->first_beat = floor(beat) + 1;
            r->next_beat = r->first_beat + r->beats;
            r->armed = r->play_after = true;
        }
        break;
    case TDJ_LOOP_REC_PLAY:
        if (r->armed || r->recording) {
            r->play_after = !r->play_after;
        } else if (r->count) {
            r->playing = !r->playing;
            r->overdub = false;
            if (r->playing)
                r->position = 0;
        }
        break;
    case TDJ_LOOP_REC_UNDO:
        if (!r->playing)
            loop_recorder_clear(r);
        else if (r->layer && !r->overdub) {
            r->undone = !r->undone;
            uint64_t mask = UINT64_C(1) << (r->layer % 64);
            if (r->undone)
                r->discarded[r->layer / 64] |= mask;
            else
                r->discarded[r->layer / 64] &= ~mask;
        }
        break;
    default:
        return false;
    }
    return true;
}

static void loop_recorder_read(const loop_recorder *r, const loop_sample *sample, double *left, double *right) {
    uint16_t layer = sample->layer;
    bool discarded = layer && (r->discarded[layer / 64] & (UINT64_C(1) << (layer % 64)));
    *left = discarded ? sample->previous_left : sample->left;
    *right = discarded ? sample->previous_right : sample->right;
}

static void loop_recorder_render(loop_recorder *r, double beat, double beats_per_frame, unsigned smoothing,
                                 double *left, double *right) {
    if (r->armed && beat >= r->first_beat) {
        r->armed = false;
        r->recording = true;
    }
    if (r->recording) {
        if (beat >= r->next_beat || r->count == r->capacity) {
            loop_recorder_finish(r, fmin(beat, r->next_beat) - r->first_beat);
        } else {
            r->samples[r->count++] = (loop_sample){.left = (float)*left, .right = (float)*right};
            return;
        }
    }
    double target = r->playing ? r->wet : 0;
    if (target != r->mix.target)
        ramp_set(&r->mix, target, smoothing);
    if (!r->count || (!r->playing && !r->mix.remaining))
        return;

    uint32_t index = (uint32_t)r->position;
    uint32_t next = index + 1 == r->count ? 0 : index + 1;
    double l, rr, next_l, next_r;
    loop_recorder_read(r, &r->samples[index], &l, &rr);
    loop_recorder_read(r, &r->samples[next], &next_l, &next_r);
    double fraction = r->position - index;
    double step = beats_per_frame * r->count / r->length_beats;
    if (r->overdub) {
        // Write each crossed frame once, including when the master tempo changes.
        uint32_t end = (uint32_t)(r->position + fmin(step, 16));
        for (uint32_t at = index; at < end; ++at) {
            loop_sample *sample = &r->samples[at % r->count];
            double old_l, old_r;
            loop_recorder_read(r, sample, &old_l, &old_r);
            if (sample->layer != r->layer) {
                sample->previous_left = (float)old_l;
                sample->previous_right = (float)old_r;
                sample->layer = (uint16_t)r->layer;
            }
            sample->left = (float)fmin(4, fmax(-4, old_l + *left));
            sample->right = (float)fmin(4, fmax(-4, old_r + *right));
        }
    }
    r->position += step;
    if (r->position >= r->count)
        r->position = fmod(r->position, r->count);
    double mix = ramp_next(&r->mix);
    *left += (l + (next_l - l) * fraction - *left) * mix;
    *right += (rr + (next_r - rr) * fraction - *right) * mix;
}

#endif
