static unsigned handoff_drain(tdj_engine *e) {
    unsigned count = 0;
    tdj_message message{};
    while (tdj_read_message(e, &message)) {
        assert(message.status == TDJ_OK);
        ++count;
    }
    return count;
}
static void handoff_submit_no_ack(tdj_engine *e, tdj_command c) {
    c.id = serial++;
    assert(tdj_submit(e, c));
    assert(tdj_render(e, 0, nullptr, nullptr));
}
static void handoff_trial(const char *path, uint64_t frames, unsigned callback, bool held, bool full, bool saturated) {
    uint32_t maximum = callback == 30000 ? 30000 : 16384;
    tdj_stream_config config{48000, 2, 1, maximum, 0};
    int32_t error = 0;
    auto *asset = tdj_asset_open_stream(path, frames, 96000, &config, &error);
    assert(asset);
    auto *engine = tdj_engine_create(48000, 1);
    assert(engine);
    assert(tdj_engine_configure_maximum_output_frames(engine, maximum) == TDJ_OK);
    auto tempo = action(TDJ_TEMPO);
    tempo.value = 120;
    assert(command(engine, tempo) == TDJ_OK);
    tdj_stream_target target{};
    target.position = target.continuing_position = 480000;
    target.source_speed = 8;
    target.performance_rate = 4;
    target.keylock = full ? 1 : 0;
    tdj_stream_request request{}, minimum{};
    assert(tdj_asset_plan_minimum(asset, &target, serial++, 1, &minimum) > 0);
    assert((full ? tdj_asset_plan_target(asset, &target, serial++, 1, &request)
                 : tdj_asset_plan_minimum(asset, &target, serial++, 1, &request)) > 0);
    if (saturated) {
        uint64_t extra = 240 - request_blocks(request).size();
        request.ranges[request.count++] = {8192ull * 700, 8192ull * (700 + extra), 1, 0};
        assert(request_blocks(request).size() == 240);
    }
    auto ticket = tdj_asset_request_prepare(asset, &request);
    assert(ticket);
    if (saturated)
        assert(tdj_asset_service(asset, 512) >= 0);
    for (unsigned n = 0; n < 512 && tdj_asset_prepare_status(asset, ticket) == TDJ_STREAM_PENDING; n++)
        assert(tdj_asset_service(asset, 16) >= 0);
    assert(tdj_asset_prepare_status(asset, ticket) == TDJ_STREAM_READY);
    auto load = action(TDJ_LOAD);
    load.asset = asset;
    load.value = 480000;
    load.value2 = 15;
    load.flag = full ? 9 : 1;
    load.preparation_ticket = ticket;
    handoff_submit_no_ack(engine, load);
    auto rate = action(TDJ_RATE);
    rate.value = 4;
    handoff_submit_no_ack(engine, rate);
    handoff_submit_no_ack(engine, action(TDJ_PLAY));
    // Establish live-table handoff without advancing audio. Native ownership can
    // retire independently of the undrained producer acknowledgement.
    if (!saturated)
        for (int i = 0; i < 4; i++) {
            assert(tdj_asset_service(asset, 16) >= 0);
            assert(tdj_render(engine, 0, nullptr, nullptr));
        }
    uint64_t nativeAck = tdj_stream_acknowledged_request(asset);
    assert(saturated || nativeAck >= 3);
    tdj_snapshot state{};
    assert(tdj_read_snapshot(engine, &state));
    assert(state.a.state == TDJ_PLAYING && state.a.source_frame == 480000 && state.a.performance_rate == 4);
    unsigned acknowledgements = 0;
    if (!held) {
        acknowledgements += handoff_drain(engine);
        tdj_asset_release_preparation(asset, ticket);
    }
    int ownership = tdj_stream_check_ticket(asset, ticket, 1);
    assert(ownership == TDJ_STALE);
    assert(tdj_asset_prepare_status(asset, ticket) == TDJ_STREAM_INVALID);
    auto reuse = action(TDJ_JUMP);
    reuse.value = 480000;
    reuse.preparation_ticket = ticket;
    reuse.id = serial++;
    assert(tdj_submit(engine, reuse));
    assert(tdj_render(engine, 0, nullptr, nullptr));
    std::vector<float> l(callback), r(callback);
    uint64_t capacityReturns = 0, pendingReturns = 0, rendered = 0;
    unsigned firstBad = UINT32_MAX, callbacks = callback == 512 ? 128 : callback == 30000 ? 3 : 6;
    for (unsigned n = 0; n < callbacks; n++) {
        assert(tdj_render(engine, callback, l.data(), r.data()));
        rendered += callback;
        tdj_stream_telemetry t{};
        tdj_asset_stream_telemetry(asset, &t);
        if (t.missing_output_frames && firstBad == UINT32_MAX)
            firstBad = n;
        for (int p = 0; p < 16; p++) {
            int status = tdj_asset_service(asset, 16);
            if (status == TDJ_STREAM_CAPACITY)
                capacityReturns++;
            else {
                assert(status >= 0);
                if (status == TDJ_STREAM_PENDING)
                    pendingReturns++;
            }
        }
    }
    tdj_stream_telemetry before{};
    tdj_asset_stream_telemetry(asset, &before);
    if (held)
        tdj_asset_release_preparation(asset, ticket);
    for (int p = 0; p < 32; p++) {
        int status = tdj_asset_service(asset, 16);
        assert(status >= 0 || status == TDJ_STREAM_CAPACITY);
        assert(tdj_render(engine, 0, nullptr, nullptr));
    }
    tdj_stream_telemetry recovered{};
    tdj_asset_stream_telemetry(asset, &recovered);
    assert(tdj_render(engine, 512, l.data(), r.data()));
    tdj_asset_stream_telemetry(asset, &recovered);
    tdj_message message{};
    unsigned stale = 0;
    while (tdj_read_message(engine, &message)) {
        if (message.command_id == reuse.id) {
            assert(message.status == TDJ_STALE);
            stale++;
        } else {
            assert(message.status == TDJ_OK);
            acknowledgements++;
        }
    }
    assert(stale == 1);
    assert(!before.source_read_misses && !before.missing_output_frames && !before.io_errors);
    assert(!recovered.source_read_misses && !recovered.missing_output_frames);
    printf("{\"callbackFrames\":%u,\"maximumFrames\":%u,\"heldProducer\":%s,\"fullPreparation\":%s,"
           "\"saturatedOptionalTable\":%s,\"minimumBlocks\":%zu,\"preparedBlocks\":%zu,\"nativeHandoffSerial\":%llu,"
           "\"ticketOwnershipStatus\":%d,\"callbacks\":%u,\"firstBadCallbackZeroBased\":%u,\"renderedFrames\":%llu,"
           "\"sourceReadMisses\":%llu,\"missingOutputFrames\":%llu,\"firstMissingOutputFrame\":%llu,"
           "\"serviceCapacityReturns\":%llu,\"servicePendingReturns\":%llu,\"capacityFailureTelemetry\":%llu,"
           "\"retirementBackpressure\":%llu,\"ioErrors\":%llu,\"lateReleaseDeltaMisses\":%llu,"
           "\"lateReleaseDeltaMissingFrames\":%llu,\"acknowledgements\":%u,\"allocatedPCMBytes\":%llu}\n",
           callback, maximum, held ? "true" : "false", full ? "true" : "false", saturated ? "true" : "false",
           request_blocks(minimum).size(), request_blocks(request).size(), (unsigned long long)nativeAck, ownership,
           callbacks, firstBad, (unsigned long long)rendered, (unsigned long long)before.source_read_misses,
           (unsigned long long)before.missing_output_frames, (unsigned long long)before.first_missing_output_frame,
           (unsigned long long)capacityReturns, (unsigned long long)pendingReturns,
           (unsigned long long)before.capacity_failures, (unsigned long long)before.retirement_backpressure,
           (unsigned long long)before.io_errors,
           (unsigned long long)(recovered.source_read_misses - before.source_read_misses),
           (unsigned long long)(recovered.missing_output_frames - before.missing_output_frames), acknowledgements,
           (unsigned long long)before.resident_pcm_bytes);
    tdj_engine_destroy(engine);
    tdj_asset_destroy(asset);
    assert(tdj_stream_reserved_pcm_bytes() == 0);
}

static void handoff_ownership_checks(const char *path, uint64_t frames) {
    tdj_stream_config config{48000, 2, 1, 16384, 0};
    int32_t error = 0;
    auto *asset = tdj_asset_open_stream(path, frames, 96000, &config, &error);
    assert(asset);
    auto *engine = tdj_engine_create(48000, 1);
    assert(engine);
    auto tempo = action(TDJ_TEMPO);
    tempo.value = 120;
    assert(command(engine, tempo) == TDJ_OK);
    auto ticket = prepare(asset, nullptr, 480000, 1, 8, false);
    auto load = action(TDJ_LOAD);
    load.asset = asset;
    load.value = 480000;
    load.value2 = 15;
    load.flag = 1;
    load.preparation_ticket = ticket;
    assert(command(engine, load) == TDJ_OK);
    tdj_asset_release_preparation(asset, ticket);
    // A still-unconsumed READY reservation fits at normal rate, but a later
    // admitted fast gesture must revoke it rather than starve live audio.
    tdj_stream_request far{};
    far.request_id = serial++;
    far.deck_generation = 1;
    far.count = 1;
    far.ranges[0] = {8192ull * 700, 8192ull * 850, 0, 0};
    auto unconsumed = tdj_asset_request_prepare(asset, &far);
    assert(unconsumed);
    for (int n = 0; n < 64 && tdj_asset_prepare_status(asset, unconsumed) == TDJ_STREAM_PENDING; n++) {
        assert(tdj_asset_service(asset, 16) >= 0);
        assert(tdj_render(engine, 0, nullptr, nullptr));
    }
    assert(tdj_asset_prepare_status(asset, unconsumed) == TDJ_STREAM_READY);
    assert(tdj_engine_configure_maximum_output_frames(engine, 65536) == TDJ_OK);
    assert(tdj_render(engine, 0, nullptr, nullptr));
    for (int n = 0; n < 16; n++) {
        assert(tdj_asset_service(asset, 16) >= 0);
        assert(tdj_render(engine, 0, nullptr, nullptr));
    }
    assert(tdj_asset_prepare_status(asset, unconsumed) == TDJ_STREAM_CAPACITY);
    assert(tdj_stream_check_ticket(asset, unconsumed, 1) == TDJ_SOURCE_CAPACITY);
    tdj_asset_release_preparation(asset, unconsumed);
    assert(command(engine, action(TDJ_PLAY)) == TDJ_OK);
    std::vector<float> l(16384), r(16384);
    for (int n = 0; n < 4; n++) {
        assert(tdj_render(engine, 16384, l.data(), r.data()));
        for (int p = 0; p < 16; p++)
            assert(tdj_asset_service(asset, 16) >= 0);
    }
    tdj_stream_telemetry telemetry{};
    tdj_asset_stream_telemetry(asset, &telemetry);
    assert(telemetry.capacity_failures == 1 && !telemetry.source_read_misses && !telemetry.missing_output_frames);
    tdj_engine_destroy(engine);
    tdj_asset_destroy(asset);
    // A single global command can consume one shared ticket for two decks.
    config.max_output_frames = 512;
    asset = tdj_asset_open_stream(path, frames, 48000, &config, &error);
    assert(asset);
    engine = tdj_engine_create(48000, 1);
    assert(engine);
    for (int deck = 0; deck < 2; deck++) {
        ticket = prepare(asset, deck ? engine : nullptr, 0);
        load = action(TDJ_LOAD, deck);
        load.asset = asset;
        load.value2 = 120;
        load.flag = 1;
        load.preparation_ticket = ticket;
        assert(command(engine, load) == TDJ_OK);
        tdj_asset_release_preparation(asset, ticket);
    }
    ticket = prepare(asset, engine, 0);
    tempo = action(TDJ_TEMPO);
    tempo.value = 120;
    tempo.preparation_ticket = tempo.preparation_ticket_b = ticket;
    tempo.preparation_generation_b = 1;
    assert(command(engine, tempo) == TDJ_OK);
    assert(tdj_asset_prepare_status(asset, ticket) == TDJ_STREAM_INVALID);
    assert(command(engine, tempo) == TDJ_STALE);
    for (int n = 0; n < 4; n++) {
        assert(tdj_asset_service(asset, 16) >= 0);
        assert(tdj_render(engine, 0, nullptr, nullptr));
    }
    tdj_asset_release_preparation(asset, ticket);
    tdj_engine_destroy(engine);
    tdj_asset_destroy(asset);
    assert(!tdj_stream_reserved_pcm_bytes());
}
static void output_readiness_checks(const char *path, uint64_t frames) {
    assert(tdj_engine_output_sources_ready(nullptr) == TDJ_INVALID);
    tdj_stream_config config{48000, 2, 1, 512, 0};
    int32_t error = 0;
    auto *asset = tdj_asset_open_stream(path, frames, 96000, &config, &error);
    assert(asset);
    auto *engine = tdj_engine_create(48000, 1);
    assert(engine);
    assert(tdj_engine_output_sources_ready(engine) == TDJ_OK);
    auto tempo = action(TDJ_TEMPO);
    tempo.value = 120;
    assert(command(engine, tempo) == TDJ_OK);
    auto ticket = prepare(asset, nullptr, 480000, 1, 8, false, 0, 0, -1, 4);
    auto load = action(TDJ_LOAD);
    load.asset = asset;
    load.value = 480000;
    load.value2 = 15;
    load.flag = 1;
    load.preparation_ticket = ticket;
    assert(command(engine, load) == TDJ_OK);
    tdj_asset_release_preparation(asset, ticket);
    auto rate = action(TDJ_RATE);
    rate.value = 4;
    assert(command(engine, rate) == TDJ_OK);
    assert(command(engine, action(TDJ_PLAY)) == TDJ_OK);
    assert(tdj_engine_output_sources_ready(engine) == TDJ_OK);
    assert(tdj_engine_configure_maximum_output_frames(engine, 16384) == TDJ_OK);
    tdj_snapshot before{}, after{};
    assert(tdj_read_snapshot(engine, &before));
    uint64_t acknowledged = tdj_stream_acknowledged_request(asset);
    for (int n = 0; n < 8; n++)
        assert(tdj_engine_output_sources_ready(engine) == TDJ_SOURCE_COLD);
    assert(tdj_read_snapshot(engine, &after));
    assert(!std::memcmp(&before, &after, sizeof(before)));
    assert(tdj_stream_acknowledged_request(asset) == acknowledged);
    assert(tdj_render(engine, 0, nullptr, nullptr));
    tdj_stream_target target{};
    target.position = target.continuing_position = 480000;
    target.source_speed = 8;
    target.performance_rate = 4;
    tdj_stream_request required{};
    assert(tdj_asset_plan_minimum(asset, &target, serial++, 1, &required) > 0);
    ticket = tdj_asset_request_prepare(asset, &required);
    assert(ticket);
    for (int n = 0; n < 32 && tdj_asset_prepare_status(asset, ticket) == TDJ_STREAM_PENDING; n++)
        assert(tdj_asset_service(asset, 16) >= 0);
    assert(tdj_asset_prepare_status(asset, ticket) == TDJ_STREAM_READY);
    // READY publication is not proof that the current audio table has adopted it.
    assert(tdj_engine_output_sources_ready(engine) == TDJ_SOURCE_COLD);
    assert(tdj_render(engine, 0, nullptr, nullptr));
    assert(tdj_engine_output_sources_ready(engine) == TDJ_OK);
    tdj_asset_release_preparation(asset, ticket);
    // Paused and native-first ready decks validate on their next Play, not here.
    assert(command(engine, action(TDJ_PLAY)) == TDJ_OK);
    tdj_stream_set_maximum_output_frames(asset, 65536);
    assert(tdj_engine_output_sources_ready(engine) == TDJ_OK);
    tdj_engine_destroy(engine);
    tdj_asset_destroy(asset);
    config.max_output_frames = 512;
    asset = tdj_asset_open_stream(path, frames, 48000, &config, &error);
    assert(asset);
    engine = tdj_engine_create(48000, 1);
    assert(engine);
    tempo = action(TDJ_TEMPO);
    tempo.value = 120;
    assert(command(engine, tempo) == TDJ_OK);
    ticket = prepare(asset, nullptr, 0);
    load = action(TDJ_LOAD);
    load.asset = asset;
    load.value2 = 1000;
    load.flag = 1;
    load.preparation_ticket = ticket;
    assert(command(engine, load) == TDJ_OK);
    tdj_asset_release_preparation(asset, ticket);
    assert(tdj_engine_output_sources_ready(engine) == TDJ_OK);
    tdj_engine_destroy(engine);
    tdj_asset_destroy(asset);
    assert(!tdj_stream_reserved_pcm_bytes());
    puts("Output readiness checks current active coverage without adoption/state changes; READY pending alone is COLD; "
         "ready/paused decks are excluded.");
}
static void streaming_handoff_checks() {
    char path[] = "/tmp/tdj-handoff-XXXXXX";
    int fd = mkstemp(path);
    assert(fd >= 0);
    uint64_t frames = 96000 * 90ull;
    assert(ftruncate(fd, frames * 8) == 0);
    close(fd);
    for (bool saturated : {false, true})
        for (bool full : {false, true})
            for (unsigned callback : {512u, 16384u})
                for (bool held : {false, true})
                    handoff_trial(path, frames, callback, held, full, saturated);
    for (bool saturated : {false, true})
        for (bool held : {false, true})
            handoff_trial(path, frames, 30000, held, false, saturated);
    handoff_ownership_checks(path, frames);
    output_readiness_checks(path, frames);
    unlink(path);
    puts("Handoff with stalled ACK collection, saturated optional tables, single-use/shared tickets and READY "
         "revocation passed.");
}
