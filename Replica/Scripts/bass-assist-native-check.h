namespace bass_checks {
struct Pair {
    double rate;
    std::vector<float> a, b;
    tdj_asset *assets[2];
    tdj_engine *plain, *assisted;

    Pair(double rate, double hz = 50, double polarity = -1, int stereo = 0) : rate(rate) {
        a.resize((int)rate * 6 * 2);
        b.resize(a.size());
        for (unsigned i = 0; i < a.size() / 2; ++i) {
            float x = .3f * sin(2 * 3.141592653589793 * hz * i / rate + .73);
            a[2 * i] = x;
            a[2 * i + 1] = stereo == 1 ? -x : stereo == 2 ? 0 : x;
            b[2 * i] = stereo == 2 ? 0 : x * polarity;
            b[2 * i + 1] = x * polarity * (stereo == 1 ? -1 : 1);
        }
        assets[0] = tdj_asset_create(a.data(), a.size() / 2, rate);
        assets[1] = tdj_asset_create(b.data(), b.size() / 2, rate);
        assert(assets[0] && assets[1]);
        plain = tdj_engine_create(rate, .5);
        assisted = tdj_engine_create(rate, .5);
        assert(plain && assisted);
        for (auto e : {plain, assisted}) {
            for (int i = 0; i < 2; ++i) {
                command(e, TDJ_LOAD, i, 0, 120, 0, 0, assets[i]);
                mixer(e, TDJ_MIX_CUE, 1, i);
            }
        }
    }
    ~Pair() {
        tdj_engine_destroy(plain);
        tdj_engine_destroy(assisted);
        tdj_asset_destroy(assets[0]);
        tdj_asset_destroy(assets[1]);
    }
    void start(bool second = true) {
        for (auto e : {plain, assisted}) {
            command(e, TDJ_PLAY, 0);
            if (second)
                command(e, TDJ_PLAY, 1);
        }
    }
    Audio warm(tdj_engine *e, double seconds = .5, int block = 128) {
        return render(e, (int)(rate * seconds), block);
    }
};

static double energy(const Audio &a, unsigned skip = 0) {
    double sum = 0;
    for (unsigned i = skip; i < a.l.size(); ++i)
        sum += a.l[i] * a.l[i] + a.r[i] * a.r[i];
    return sum / (a.l.size() - skip);
}

static void identical(const Audio &a, const Audio &b) {
    assert(a.l == b.l && a.r == b.r && a.cl == b.cl && a.cr == b.cr);
}

static void observe(double rate) {
    Pair p(rate, 73, -.7, 1);
    tdj_bass_assist_set_mode(p.assisted, TDJ_BASS_MEASURE);
    p.start();
    identical(p.warm(p.plain), p.warm(p.assisted));
    auto m = tdj_bass_assist_read(p.assisted);
    assert(m.available && m.correlation < -.999 && m.cancellation_db > 10);
    assert(m.reduction_a_db == 0 && m.reduction_b_db == 0 && m.leader == -1);
    auto a = snapshot(p.plain), b = snapshot(p.assisted);
    assert(a.a.source_frame == b.a.source_frame && a.b.source_frame == b.b.source_frame);
}

static void cancellation_and_cue(double rate) {
    Pair p(rate, 50, -1, 1);
    tdj_bass_assist_set_mode(p.assisted, TDJ_BASS_HANDOVER);
    p.start();
    auto plain = p.warm(p.plain), mixed = p.warm(p.assisted);
    assert(energy(plain) < 1e-15 && energy(mixed, (unsigned)(rate * .3)) > .01);
    assert(plain.cl == mixed.cl && plain.cr == mixed.cr);
    for (unsigned i = 0; i < mixed.l.size(); ++i)
        assert(fabs(mixed.l[i] + mixed.r[i]) < 1e-7);
    auto m = tdj_bass_assist_read(p.assisted);
    assert(m.available && m.leader == 0 && m.correlation < -.999 && m.cancellation_db > 50);
    assert(m.reduction_a_db == 0 && m.reduction_b_db > 11.99 && m.reduction_b_db <= 12.000001);
    auto a = snapshot(p.plain), b = snapshot(p.assisted);
    assert(a.a.source_frame == b.a.source_frame && a.b.source_frame == b.b.source_frame);
    auto ring = tdj_recording_create(4096);
    assert(ring);
    tdj_recording_start(ring);
    auto recorded = render(p.assisted, 4096, 128, ring);
    tdj_recording_stop(ring);
    std::vector<float> l(4096), r(4096);
    assert(tdj_recording_read(ring, 4096, l.data(), r.data()) == 4096);
    assert(l == recorded.l && r == recorded.r);
    tdj_recording_destroy(ring);
}

static void reinforcement(double rate) {
    Pair p(rate, 50, 1);
    tdj_bass_assist_set_mode(p.assisted, TDJ_BASS_HANDOVER);
    p.start();
    auto a = p.warm(p.plain), b = p.warm(p.assisted);
    double before = energy(a, (unsigned)(rate * .3)), after = energy(b, (unsigned)(rate * .3));
    assert(after > before * .25 && after < before * .6);
    auto m = tdj_bass_assist_read(p.assisted);
    assert(m.available && m.correlation > .999 && m.cancellation_db == 0);
}

static void bypass(double rate, int kind) {
    Pair p(rate, kind == 1 ? 4000 : 50, 1, kind == 2 ? 2 : 0);
    tdj_bass_assist_set_mode(p.assisted, TDJ_BASS_HANDOVER);
    for (auto e : {p.plain, p.assisted}) {
        if (kind == 3 || kind == 4)
            mixer(e, TDJ_MIX_CROSSFADE, kind == 3 ? 0 : 1);
        if (kind == 5)
            mixer(e, TDJ_MIX_CROSSFADE_ASSIGNMENT, 0, 1);
        if (kind == 6) {
            assert(tdj_engine_prepare_extra_decks(e));
            command(e, TDJ_LOAD, 2, 0, 120, 0, 0, p.assets[0]);
        }
        if (kind == 7) {
            mixer(e, TDJ_MIX_FILTER_X, .8, 1);
            mixer(e, TDJ_MIX_FILTER_ENABLED, 1, 1);
        }
    }
    p.start(kind != 0);
    auto a = p.warm(p.plain), b = p.warm(p.assisted);
    if (a.l != b.l || a.r != b.r || a.cl != b.cl || a.cr != b.cr)
        std::fprintf(stderr, "bypass %.0f Hz kind %d changed output\n", rate, kind);
    identical(a, b);
    auto m = tdj_bass_assist_read(p.assisted);
    if (m.available || m.reduction_a_db != 0 || m.reduction_b_db != 0)
        std::fprintf(stderr, "bypass %.0f Hz kind %d: available=%d reductions %.9f %.9f\n", rate, kind, m.available,
                     m.reduction_a_db, m.reduction_b_db);
    assert(!m.available && m.reduction_a_db == 0 && m.reduction_b_db == 0);
}

static void takeover_and_release(double rate) {
    Pair p(rate);
    tdj_bass_assist_set_mode(p.assisted, TDJ_BASS_HANDOVER);
    p.start();
    p.warm(p.plain);
    p.warm(p.assisted);
    for (double position : {.46, .54, .49, .53}) {
        for (auto e : {p.plain, p.assisted})
            mixer(e, TDJ_MIX_CROSSFADE, position);
        p.warm(p.plain, .02);
        p.warm(p.assisted, .02);
        assert(tdj_bass_assist_read(p.assisted).leader == 0);
    }
    for (auto e : {p.plain, p.assisted})
        mixer(e, TDJ_MIX_CROSSFADE, .7);
    p.warm(p.plain);
    auto right = p.warm(p.assisted);
    auto m = tdj_bass_assist_read(p.assisted);
    assert(m.leader == 1 && m.reduction_a_db > 1 && m.reduction_b_db == 0);
    for (auto e : {p.plain, p.assisted})
        mixer(e, TDJ_MIX_CROSSFADE, .5);
    p.warm(p.plain);
    p.warm(p.assisted);
    assert(tdj_bass_assist_read(p.assisted).leader == 1);
    tdj_bass_assist_set_mode(p.assisted, TDJ_BASS_OFF);
    auto plain = p.warm(p.plain, .35), off = p.warm(p.assisted, .35);
    for (unsigned i = (unsigned)(rate * .26); i < off.l.size(); ++i)
        assert(plain.l[i] == off.l[i] && plain.r[i] == off.r[i]);
    for (unsigned i = 1; i < off.l.size(); ++i)
        assert(fabs(off.l[i] - off.l[i - 1]) < .01);
    assert(!tdj_bass_assist_read(p.assisted).available);
    identical(p.warm(p.plain, .1), p.warm(p.assisted, .1));
}

static void earlier_deck(double rate) {
    Pair p(rate);
    tdj_bass_assist_set_mode(p.assisted, TDJ_BASS_HANDOVER);
    command(p.assisted, TDJ_PLAY, 1);
    p.warm(p.assisted, .1);
    command(p.assisted, TDJ_PLAY, 0);
    p.warm(p.assisted);
    assert(tdj_bass_assist_read(p.assisted).leader == 1);
}

static void reload_and_pause(double rate) {
    Pair p(rate);
    tdj_bass_assist_set_mode(p.assisted, TDJ_BASS_HANDOVER);
    p.start();
    p.warm(p.assisted);
    assert(tdj_bass_assist_read(p.assisted).available);
    command(p.assisted, TDJ_PLAY, 1);
    assert(!tdj_bass_assist_read(p.assisted).available);
    command(p.assisted, TDJ_PLAY, 1);
    p.warm(p.assisted);
    assert(tdj_bass_assist_read(p.assisted).available);
    command(p.assisted, TDJ_PLAY, 1);
    tdj_command load{};
    load.kind = TDJ_LOAD;
    load.deck = 1;
    load.generation = 99;
    load.id = serial++;
    load.asset = p.assets[1];
    load.value2 = 120;
    assert(tdj_submit(p.assisted, load));
    assert(tdj_render(p.assisted, 0, nullptr, nullptr));
    tdj_message message{};
    bool accepted = false;
    while (tdj_read_message(p.assisted, &message))
        if (message.command_id == load.id) {
            assert(message.status == TDJ_OK);
            accepted = true;
        }
    assert(accepted && !tdj_bass_assist_read(p.assisted).available);
    assert(snapshot(p.assisted).b.generation == 99);
}

static void block_size_invariance(double rate) {
    Pair p(rate);
    tdj_bass_assist_set_mode(p.plain, TDJ_BASS_HANDOVER);
    tdj_bass_assist_set_mode(p.assisted, TDJ_BASS_HANDOVER);
    p.start();
    identical(p.warm(p.plain, .5, 17), p.warm(p.assisted, .5, 257));
}

static void active_endpoint(double rate) {
    Pair p(rate);
    tdj_bass_assist_set_mode(p.assisted, TDJ_BASS_HANDOVER);
    p.start();
    p.warm(p.plain);
    p.warm(p.assisted);
    for (double cross : {1., 0.}) {
        for (auto e : {p.plain, p.assisted})
            mixer(e, TDJ_MIX_CROSSFADE, cross);
        p.warm(p.plain, .01);
        p.warm(p.assisted, .01);
        identical(p.warm(p.plain, .1), p.warm(p.assisted, .1));
    }
}

static void mode_and_control_stress(double rate) {
    Pair p(rate);
    p.start();
    std::atomic<bool> done{false};
    std::thread reader([&] {
        while (!done) {
            auto m = tdj_bass_assist_read(p.assisted);
            assert(std::isfinite(m.correlation) && fabs(m.correlation) <= 1);
            assert(std::isfinite(m.cancellation_db) && m.cancellation_db >= 0 && m.cancellation_db <= 60.000001);
            assert(m.reduction_a_db >= -1e-9 && m.reduction_a_db <= 12.000001);
            assert(m.reduction_b_db >= -1e-9 && m.reduction_b_db <= 12.000001);
        }
    });
    for (int i = 0; i < 250; ++i) {
        tdj_bass_assist_set_mode(p.assisted, i % 3);
        mixer(p.assisted, TDJ_MIX_CROSSFADE, (i % 11) / 10.);
        auto block = render(p.assisted, 128);
        bounded(block, .31);
    }
    done = true;
    reader.join();
    tdj_bass_assist_set_mode(p.assisted, TDJ_BASS_MEASURE);
    p.warm(p.assisted, .35);
    auto m = tdj_bass_assist_read(p.assisted);
    assert(m.reduction_a_db == 0 && m.reduction_b_db == 0);
    auto s = snapshot(p.assisted);
    assert(s.a.low == 1 && s.b.low == 1 && !s.a.synced && !s.b.synced);
}

static void run() {
    setvbuf(stdout, nullptr, _IONBF, 0);
    for (double rate : {44100., 48000., 96000.}) {
        observe(rate);
        cancellation_and_cue(rate);
        reinforcement(rate);
        for (int kind = 0; kind < 8; ++kind)
            bypass(rate, kind);
        takeover_and_release(rate);
        earlier_deck(rate);
        reload_and_pause(rate);
        block_size_invariance(rate);
        active_endpoint(rate);
        mode_and_control_stress(rate);
        std::printf("%.0f Hz: 17 bass cases passed: exact observation/bypass, cancellation, stereo, cue/recording, "
                    "leader hysteresis, reload, block sizes, endpoints, release and concurrent meter reads.\n",
                    rate);
    }
}
} // namespace bass_checks
