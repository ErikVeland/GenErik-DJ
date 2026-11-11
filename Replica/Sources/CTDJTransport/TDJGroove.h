#ifndef TDJ_GROOVE_H
#define TDJ_GROOVE_H

typedef struct {
    int mode;
    bool target_valid, position_valid, aligned;
    double rate, master_bpm, solo_ratio, expected_position, last_beat;
    double target_beat, target_source_beat, target_frame;
} groove_sync;

/**
 * Limits automatic correction without moving the source cursor.
 */
static double groove_correct_rate(double current, double requested, double nominal, double output_rate, bool keylock,
                                  bool *limited) {
    double margin = nominal * TDJ_GROOVE_CORRECTION_PERCENT / 100;
    double lower = nominal - margin, upper = nominal + margin;
    if (keylock) {
        lower = fmax(lower, 0.125);
        upper = fmin(upper, 8);
    }
    *limited = !isfinite(requested) || requested < lower || requested > upper;
    double target = isfinite(requested) ? fmax(lower, fmin(upper, requested)) : current;
    double slew = nominal * TDJ_GROOVE_SLEW_PERCENT_PER_SECOND / (100 * output_rate);
    return current + fmax(-slew, fmin(slew, target - current));
}

#endif
