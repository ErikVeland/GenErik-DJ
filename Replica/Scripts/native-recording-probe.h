// Native stress-only writer. Uses the production capture ring and the same 24-bit AIFF format.
#import <AudioToolbox/AudioToolbox.h>
extern "C" {
#include "TDJRecording.h"
}
struct NativeRecordingProbe {
    tdj_recording *ring=nullptr;
    ExtAudioFileRef file=nullptr;
    std::atomic<bool> stopping{false};
    std::thread writer;
    std::vector<float> left=std::vector<float>(8192),right=std::vector<float>(8192);
    uint64_t frames=0,nonfinite=0;
    SInt64 fileFrames=0;
    OSStatus status=0;
    double peak=0;
    std::string path;
    bool open(const std::string &name,double rate) {
        path=name;
        ring=tdj_recording_create(uint32_t(rate*10));
        if(!ring) {status=-1;return false;}
        AudioStreamBasicDescription output{};
        output.mSampleRate=rate;output.mFormatID=kAudioFormatLinearPCM;
        output.mFormatFlags=kAudioFormatFlagIsSignedInteger|kAudioFormatFlagIsBigEndian|kAudioFormatFlagIsPacked;
        output.mBytesPerPacket=6;output.mFramesPerPacket=1;output.mBytesPerFrame=6;
        output.mChannelsPerFrame=2;output.mBitsPerChannel=24;
        NSURL *url=[NSURL fileURLWithPath:[NSString stringWithUTF8String:path.c_str()]];
        status=ExtAudioFileCreateWithURL((__bridge CFURLRef)url,kAudioFileAIFFType,&output,nullptr,0,&file);
        if(status)return false;
        AudioStreamBasicDescription client{};
        client.mSampleRate=rate;client.mFormatID=kAudioFormatLinearPCM;
        client.mFormatFlags=kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked|kAudioFormatFlagIsNonInterleaved;
        client.mBytesPerPacket=4;client.mFramesPerPacket=1;client.mBytesPerFrame=4;
        client.mChannelsPerFrame=2;client.mBitsPerChannel=32;
        status=ExtAudioFileSetProperty(file,kExtAudioFileProperty_ClientDataFormat,sizeof(client),&client);
        if(status)return false;
        tdj_recording_start(ring);
        writer=std::thread([this] {
            pthread_set_qos_class_self_np(QOS_CLASS_UTILITY,0);
            for(;;) {
                bool done=stopping.load(std::memory_order_acquire);
                uint32_t count=tdj_recording_read(ring,8192,left.data(),right.data());
                if(!count) {
                    if(done)break;
                    std::this_thread::sleep_for(std::chrono::milliseconds(20));continue;
                }
                for(uint32_t i=0;i<count;i++) {
                    if(!std::isfinite(left[i]) || !std::isfinite(right[i]))nonfinite++;
                    peak=std::max(peak,std::max(std::abs(double(left[i])),std::abs(double(right[i]))));
                }
                struct {UInt32 count;AudioBuffer buffers[2];} buffers{2,{{1,count*4,left.data()},{1,count*4,right.data()}}};
                if(!status)status=ExtAudioFileWrite(file,count,reinterpret_cast<AudioBufferList *>(&buffers));
                frames+=count;
            }
        });
        return true;
    }
    void finish() {
        if(!ring)return;
        tdj_recording_stop(ring);
        stopping.store(true,std::memory_order_release);
        if(writer.joinable())writer.join();
        if(file) {OSStatus closed=ExtAudioFileDispose(file);file=nullptr;if(!status)status=closed;}
        if(!path.empty() && !status) {
            ExtAudioFileRef saved=nullptr;
            NSURL *url=[NSURL fileURLWithPath:[NSString stringWithUTF8String:path.c_str()]];
            status=ExtAudioFileOpenURL((__bridge CFURLRef)url,&saved);
            if(!status) {
                UInt32 bytes=sizeof(fileFrames);
                status=ExtAudioFileGetProperty(saved,kExtAudioFileProperty_FileLengthFrames,&bytes,&fileFrames);
                OSStatus closed=ExtAudioFileDispose(saved);if(!status)status=closed;
            }
        }
    }
    ~NativeRecordingProbe() {
        if(writer.joinable() || file)finish();
        if(ring)tdj_recording_destroy(ring);
    }
};
