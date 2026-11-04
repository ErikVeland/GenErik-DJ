#ifndef TDJ_DLC_EFFECTS_H
#define TDJ_DLC_EFFECTS_H
// Independent bounded implementations of documented effect families. Mobile NI curves are unknown.
static void fx_begin_capture(performance_fx *f) {
    // Keep audio recorded while bypassed. A partial capture continues from live input.
    f->capture_ready = false;
    f->grain_written = 0;
    f->grain_phase = 0;
    f->capture_position = 0;
    fx_transition(f);
}
static void fx_reverse_record(performance_fx *f, const double dry[2]) {
    unsigned frames = (unsigned)fmax(2, fmin(f->capacity, floor(f->frames_per_beat)));
    if (f->capture_frames != frames) {
        f->capture_frames = frames;
        f->idle_write = 0;
        f->idle_filled = 0;
    }
    for (int ch = 0; ch < 2; ch++)
        f->buffer[2 * f->idle_write + ch] = (float)dry[ch];
    f->idle_write = f->idle_write + 1 < frames ? f->idle_write + 1 : 0;
    if (f->idle_filled < frames)
        f->idle_filled++;
}
static double fx_dlc_cyclic(const performance_fx *f, double position, unsigned length, int channel) {
    // Callers keep positions within one wrap of the valid range.
    if (position < 0)
        position += length;
    else if (position >= length)
        position -= length;
    unsigned at = (unsigned)position;
    unsigned previous = at ? at - 1 : length - 1;
    unsigned next = at + 1 < length ? at + 1 : 0;
    unsigned after = next + 1 < length ? next + 1 : 0;
    double t = position - at;
    double a = f->buffer[2 * previous + channel], b = f->buffer[2 * at + channel];
    double c = f->buffer[2 * next + channel], d = f->buffer[2 * after + channel];
    return b + 0.5 * t * (c - a + t * (2 * a - 5 * b + 4 * c - d + t * (3 * (b - c) + d - a)));
}
static double fx_dlc_delay(const performance_fx *f, double back, int channel) {
    return fx_dlc_cyclic(f, (double)f->cursor - back, f->capacity, channel);
}
static void fx_dlc_process(performance_fx *f, double rate, const double dry[2], double output[2]) {
    (void)rate;
    if (f->kind == TDJ_EFFECT_TRANSPOSE_STRETCH) {
        for (int ch = 0; ch < 2; ch++)
            f->buffer[2 * f->cursor + ch] = (float)dry[ch];
        if (f->grain_written < f->grain_frames + 4) {
            f->grain_written++;
            output[0] = dry[0];
            output[1] = dry[1];
            return;
        }
        if (!f->capture_ready) {
            f->capture_ready = true;
            if (f->grain_ratio != 1)
                fx_transition(f);
        }
        double phase = f->grain_phase;
        output[0] = output[1] = 0;
        for (int grain = 0; grain < 4; grain++) {
            double position = phase + f->grain_frames * (grain * 0.25);
            if (position >= f->grain_frames)
                position -= f->grain_frames;
            double weight = 0.25 * (1 - cos(2 * M_PI * position / f->grain_frames));
            for (int ch = 0; ch < 2; ch++)
                output[ch] += fx_dlc_delay(f, 2 + position, ch) * weight;
        }
        if (f->grain_ratio == 1) {
            output[0] = dry[0];
            output[1] = dry[1];
        }
        phase += 1 - f->grain_ratio;
        if (phase < 0)
            phase += f->grain_frames;
        else if (phase >= f->grain_frames)
            phase -= f->grain_frames;
        f->grain_phase = phase;
        return;
    }
    if (!f->capture_ready) {
        fx_reverse_record(f, dry);
        output[0] = dry[0];
        output[1] = dry[1];
        if (f->idle_filled >= f->capture_frames) {
            f->capture_ready = true;
            f->capture_position = (f->idle_write + f->capture_frames - 1) % f->capture_frames;
        }
        return;
    }
    if (!f->grain_written) {
        fx_transition(f);
        f->grain_written = 1;
    }
    unsigned grain = f->grain_frames < f->capture_frames ? f->grain_frames : f->capture_frames;
    double phase = f->grain_phase;
    if (phase >= grain)
        phase = fmod(phase, grain);
    output[0] = output[1] = 0;
    for (int window = 0; window < 4; window++) {
        double position = phase + grain * (window * 0.25);
        if (position >= grain)
            position -= grain;
        double weight = 0.25 * (1 - cos(2 * M_PI * position / grain));
        for (int ch = 0; ch < 2; ch++)
            output[ch] += fx_dlc_cyclic(f, f->capture_position - position * 0.5, f->capture_frames, ch) * weight;
    }
    f->capture_position -= 0.5;
    if (f->capture_position < 0)
        f->capture_position += f->capture_frames;
    f->grain_phase = phase + 1;
    if (f->grain_phase >= grain)
        f->grain_phase -= grain;
}
#endif
