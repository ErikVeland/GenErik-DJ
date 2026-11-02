#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#include <vector>
#include <unistd.h>

// Read Mac HAL client metadata only. Do not enumerate devices or create audio taps.
template<typename T> static OSStatus property(AudioObjectID id,AudioObjectPropertySelector selector,T &value) {
    AudioObjectPropertyAddress address{selector,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
    UInt32 bytes=sizeof(value);
    return AudioObjectGetPropertyData(id,&address,0,nullptr,&bytes,&value);
}
int main() {
    @autoreleasepool {
        AudioObjectPropertyAddress address{kAudioHardwarePropertyProcessObjectList,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
        UInt32 bytes=0;
        OSStatus status=AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,&address,0,nullptr,&bytes);
        if(status || bytes%sizeof(AudioObjectID) || bytes>1048576)return 2;
        std::vector<AudioObjectID> ids(bytes/sizeof(AudioObjectID));
        status=AudioObjectGetPropertyData(kAudioObjectSystemObject,&address,0,nullptr,&bytes,ids.data());
        if(status)return 2;
        AudioObjectID defaultOutput=0;
        OSStatus defaultStatus=property(kAudioObjectSystemObject,kAudioHardwarePropertyDefaultOutputDevice,defaultOutput);
        CFStringRef name=nullptr;if(!defaultStatus)property(defaultOutput,kAudioObjectPropertyName,name);
        NSString *outputName=CFBridgingRelease(name) ?: @"";
        pid_t hogPID=-1;OSStatus hogStatus=property(defaultOutput,kAudioDevicePropertyHogMode,hogPID);
        AudioObjectPropertyAddress hogAddress{kAudioDevicePropertyHogMode,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
        Boolean hogSettable=false;OSStatus hogSettableStatus=AudioObjectIsPropertySettable(defaultOutput,&hogAddress,&hogSettable);
        NSMutableArray *active=[NSMutableArray array];int queryErrors=0;
        for(size_t i=0;i<bytes/sizeof(AudioObjectID);++i) {
            UInt32 output=0;pid_t pid=0;
            if(property(ids[i],kAudioProcessPropertyIsRunningOutput,output)){++queryErrors;continue;}
            if(!output)continue;
            OSStatus pidStatus=property(ids[i],kAudioProcessPropertyPID,pid);
            CFStringRef bundle=nullptr;OSStatus bundleStatus=property(ids[i],kAudioProcessPropertyBundleID,bundle);
            NSString *bundleID=CFBridgingRelease(bundle) ?: @"";
            AudioObjectPropertyAddress routes{kAudioProcessPropertyDevices,kAudioObjectPropertyScopeOutput,kAudioObjectPropertyElementMain};
            UInt32 routeBytes=0;OSStatus routeStatus=AudioObjectGetPropertyDataSize(ids[i],&routes,0,nullptr,&routeBytes);
            bool usesDefault=false;
            if(!routeStatus && routeBytes%sizeof(AudioObjectID)==0 && routeBytes<=1048576) {
                std::vector<AudioObjectID> connected(routeBytes/sizeof(AudioObjectID));
                routeStatus=AudioObjectGetPropertyData(ids[i],&routes,0,nullptr,&routeBytes,connected.data());
                if(!routeStatus)for(size_t j=0;j<routeBytes/sizeof(AudioObjectID);++j)if(connected[j]==defaultOutput)usesDefault=true;
            }
            [active addObject:@{@"usesDefaultOutput":@(usesDefault),@"routeStatus":@(routeStatus),@"pid":@(pid),@"bundleID":bundleID,@"outputRunning":@YES,@"pidStatus":@(pidStatus),@"bundleStatus":@(bundleStatus)}];
        }
        NSDictionary *result=@{@"format":@"generik-dj.mac-hal-clients/v1",@"UTC":[NSDate date].description,@"queryErrors":@(queryErrors),@"activeOutputProcesses":active,@"defaultOutputName":outputName,@"defaultOutputStatus":@(defaultStatus),@"hogOwnerPID":@(hogPID),@"hogReadStatus":@(hogStatus),@"hogSettable":@(hogSettable),@"hogSettableStatus":@(hogSettableStatus),@"globalDeviceInventoryRead":@NO,@"processOutputAssociationsRead":@YES,@"audioCaptured":@NO,@"iPadAccessed":@NO};
        NSData *json=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil];
        if(!json)return 2;
        fwrite(json.bytes,1,json.length,stdout);fputc('\n',stdout);
        return queryErrors?1:0;
    }
}
