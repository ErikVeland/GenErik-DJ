#ifndef TDJ_NATIVE_RESIDENCY_DIAGNOSTIC_H
#define TDJ_NATIVE_RESIDENCY_DIAGNOSTIC_H
#include <atomic>
#include <array>
#include <vector>
#include <algorithm>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <climits>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <sys/mman.h>
#include <malloc/malloc.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>

// This Mac test-only tracker runs during construction, before device output.
struct DSPAllocationRange {
    void *address = nullptr;
    size_t bytes = 0;
    bool live = false;
};
static std::array<DSPAllocationRange, 4096> dspAllocationRanges{};
static size_t dspAllocationCount = 0;
static bool dspAllocationOverflow = false;
static std::atomic<bool> captureDSPAllocations{false};
static void recordDSPAllocation(void *p, size_t bytes) {
    if (!captureDSPAllocations.load(std::memory_order_relaxed))
        return;
    if (dspAllocationCount == dspAllocationRanges.size()) {
        dspAllocationOverflow = true;
        return;
    }
    dspAllocationRanges[dspAllocationCount++] = {p, bytes, true};
}
static void forgetDSPAllocation(void *p) {
    if (!captureDSPAllocations.load(std::memory_order_relaxed))
        return;
    for (size_t i = dspAllocationCount; i > 0; --i) {
        auto &r = dspAllocationRanges[i - 1];
        if (r.address == p && r.live) {
            r.live = false;
            return;
        }
    }
}
struct DiagnosticResidency {
    size_t page = size_t(sysconf(_SC_PAGESIZE)), liveBytes = 0, liveAllocations = 0, lockedPages = 0;
    int error = 0;
    std::vector<uintptr_t> pages;
    void *codeBacking = MAP_FAILED;
    size_t codeBackingBytes = 0;
    void addCodeBacking() {
        char path[PATH_MAX];
        uint32_t pathSize = sizeof(path);
        if (_NSGetExecutablePath(path, &pathSize)) {
            error = ENAMETOOLONG;
            return;
        }
        auto *header = reinterpret_cast<const mach_header_64 *>(_dyld_get_image_header(0));
        if (!header || header->magic != MH_MAGIC_64) {
            error = EINVAL;
            return;
        }
        auto *cursor = reinterpret_cast<const char *>(header) + sizeof(*header);
        uint64_t fileOffset = 0, fileBytes = 0;
        for (uint32_t i = 0; i < header->ncmds; ++i) {
            auto *command = reinterpret_cast<const load_command *>(cursor);
            if (command->cmd == LC_SEGMENT_64) {
                auto *segment = reinterpret_cast<const segment_command_64 *>(command);
                if (std::strncmp(segment->segname, "__TEXT", 16) == 0) {
                    fileOffset = segment->fileoff;
                    fileBytes = segment->filesize;
                    break;
                }
            }
            cursor += command->cmdsize;
        }
        if (!fileBytes || fileBytes > 32 * 1024 * 1024 || fileOffset % page) {
            error = EINVAL;
            return;
        }
        int fd = open(path, O_RDONLY);
        if (fd < 0) {
            error = errno;
            return;
        }
        struct stat info{};
        if (fstat(fd, &info) || uint64_t(info.st_size) < fileOffset + fileBytes) {
            error = EINVAL;
            close(fd);
            return;
        }
        codeBacking = mmap(nullptr, size_t(fileBytes), PROT_READ, MAP_PRIVATE, fd, off_t(fileOffset));
        close(fd);
        if (codeBacking == MAP_FAILED) {
            error = errno;
            return;
        }
        codeBackingBytes = size_t(fileBytes);
        add(codeBacking, codeBackingBytes);
    }
    void add(void *address, size_t bytes) {
        if (!address || !bytes || error)
            return;
        if (bytes > 32 * 1024 * 1024 || uintptr_t(address) > UINTPTR_MAX - bytes - page) {
            error = E2BIG;
            return;
        }
        uintptr_t begin = uintptr_t(address) / page * page;
        uintptr_t end = (uintptr_t(address) + bytes + page - 1) / page * page;
        for (auto at = begin; at < end; at += page)
            pages.push_back(at);
    }
    void addDSP(void *core) {
        if (dspAllocationOverflow) {
            error = EOVERFLOW;
            return;
        }
        add(core, malloc_size(core));
        for (auto r : dspAllocationRanges)
            if (r.live) {
                add(r.address, r.bytes);
                liveBytes += r.bytes;
                ++liveAllocations;
            }
    }
    void addText() {
        auto *header = reinterpret_cast<const mach_header_64 *>(_dyld_get_image_header(0));
        if (!header || header->magic != MH_MAGIC_64 || header->sizeofcmds > 32 * 1024 * 1024) {
            error = EINVAL;
            return;
        }
        auto *cursor = reinterpret_cast<const char *>(header) + sizeof(*header);
        auto *end = cursor + header->sizeofcmds;
        intptr_t slide = _dyld_get_image_vmaddr_slide(0);
        for (uint32_t i = 0; i < header->ncmds; ++i) {
            if (cursor + sizeof(load_command) > end) {
                error = EINVAL;
                return;
            }
            auto *command = reinterpret_cast<const load_command *>(cursor);
            if (command->cmdsize < sizeof(load_command) || cursor + command->cmdsize > end) {
                error = EINVAL;
                return;
            }
            if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(segment_command_64)) {
                auto *segment = reinterpret_cast<const segment_command_64 *>(command);
                if (std::strncmp(segment->segname, "__TEXT", 16) == 0) {
                    add(reinterpret_cast<void *>(uintptr_t(segment->vmaddr + slide)), size_t(segment->vmsize));
                    return;
                }
            }
            cursor += command->cmdsize;
        }
        error = ENOENT;
    }
    bool lock() {
        std::sort(pages.begin(), pages.end());
        pages.erase(std::unique(pages.begin(), pages.end()), pages.end());
        if (pages.size() > 32 * 1024 * 1024 / page)
            error = E2BIG;
        if (error)
            return false;
        for (auto address : pages) {
            if (mlock(reinterpret_cast<void *>(address), page)) {
                error = errno;
                return false;
            }
            ++lockedPages;
        }
        return true;
    }
    ~DiagnosticResidency() {
        for (size_t i = 0; i < lockedPages; ++i)
            munlock(reinterpret_cast<void *>(pages[i]), page);
        if (codeBacking != MAP_FAILED)
            munmap(codeBacking, codeBackingBytes);
    }
};
#endif
