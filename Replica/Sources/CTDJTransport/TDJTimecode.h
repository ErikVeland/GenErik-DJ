#ifndef TDJ_TIMECODE_H
#define TDJ_TIMECODE_H

static bool timecode_speed(const float *left, const float *right, unsigned left_stride, unsigned right_stride,
                           unsigned count, double sample_rate, double *speed) {
    if (count < 64 || count > 8192 || !left_stride || !right_stride || !isfinite(sample_rate) ||
        sample_rate < 32000 || sample_rate > 192000)
        return false;
    double cross = 0, dot = 0, left_energy = 0, right_energy = 0, product = 0;
    double raw_l = left[0], raw_r = right[0], previous_l = 0, previous_r = 0;
    if (!isfinite(raw_l) || !isfinite(raw_r))
        return false;
    for (unsigned i = 1; i < count; ++i) {
        double next_l = left[i * left_stride], next_r = right[i * right_stride];
        if (!isfinite(next_l) || !isfinite(next_r))
            return false;
        double l = next_l - raw_l, r = next_r - raw_r;
        cross += previous_l * r - previous_r * l;
        dot += previous_l * l + previous_r * r;
        left_energy += l * l;
        right_energy += r * r;
        product += l * r;
        previous_l = l;
        previous_r = r;
        raw_l = next_l;
        raw_r = next_r;
    }
    double energy = left_energy + right_energy;
    if (left_energy < count * 0.00000025 || right_energy < count * 0.00000025 ||
        fabs(product) > 0.28 * sqrt(left_energy * right_energy) ||
        hypot(cross, dot) < energy * 0.80)
        return false;
    double rate = atan2(cross, dot) * sample_rate / (2 * 3.141592653589793 * 2500);
    if (!isfinite(rate) || fabs(rate) < 0.035 || fabs(rate) > 4)
        return false;
    *speed = rate;
    return true;
}

#endif
